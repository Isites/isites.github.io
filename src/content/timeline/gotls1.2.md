---
title: "码了2000多行代码就是为了讲清楚TLS握手流程（续）"
date: 2020-12-13T23:47:48+08:00
draft: true
toc: true
images:
tags:
  - Go
  - 网络篇
---

在“[码了2000多行代码就是为了讲清楚TLS握手流程](https://mp.weixin.qq.com/s/ALmouugbrCHrNbyk3OTtSQ)”这一篇文章的最后挖了一个坑，今天这篇文章就是为了填坑而来，因此本篇主要分析TLS1.2的握手流程。

在写前一篇文章时，笔者的Demo只支持解析TLS1.3握手流程中发送的消息，写本篇时，笔者的Demo已经可以解析TLS1.x握手流程中的消息，有兴趣的读者请至文末获取Demo源码。

### 结论先行

为保证各位读者对TLS1.2的握手流程有一个大概的框架，本篇依旧结论先行。

#### 单向认证

单向认证客户端不需要证书，客户端验证服务端证书合法即可访问。

下面是笔者运行Demo打印的调试信息：

![](https://note.youdao.com/yws/api/personal/file/WEB7b4e407a4d300561e2889311bff03b7f?method=download&shareKey=df9641649e598375a3c8bc5baaa93fe9)

根据调试信息知，TLS1.2单向认证中总共收发数据**四次**，Client和Server从这四次数据中分别读取不同的信息以达到握手的目的。

笔者将调试信息转换为下述时序图，以方便各位读者理解。


![](https://note.youdao.com/yws/api/personal/file/WEBe8229b8e38739b1e3cbe114c158d8a98?method=download&shareKey=1a4a0f4fe5bd9d2b9e6406b4575fe312)

#### 双向认证

双向认证不仅服务端要有证书，客户端也需要证书，只有客户端和服务端证书均合法才可继续访问（笔者的Demo如何开启双向认证请参考前一篇文章中HTTPS双向认证部分）。

下面是笔者运行Demo打印的调试信息：

![](https://note.youdao.com/yws/api/personal/file/WEB87df88f5543af04290af0c21dca8c17a?method=download&shareKey=2fec2f1d33ffb7dd40c0b47a19c6eb83)

同单向认证一样，笔者将调试信息转换为下述时序图。

![](https://note.youdao.com/yws/api/personal/file/WEB7cafa6a349cf1fff0e319767af00dfb1?method=download&shareKey=df90677bde25f8ef809ddd93365759e2)

双向认证和单向认证相比，Server发消息给Client时会额外发送一个`certificateRequestMsg`消息，Client收到此消息后会将证书信息（`certificateMsg`）和签名信息（`certificateVerifyMsg`）发送给Server。

双向认证中，Client和Server发送的消息变多了，但是总的数据收发仍然只有**四次**。


#### 总结

1、单向认证和双向认证中，总的数据收发仅四次（比TLS1.3多一次数据收发），单次发送的数据中包含一个或者多个消息。

2、TLS1.2中除了`finishedMsg`其余消息均未加密。

3、在TLS1.2中，`ChangeCipherSpec`消息之后的所有数据均会做加密处理，它的作用在TLS1.2中更像是一个开启加密的开关（TLS1.3中忽略此消息，并不做任何处理）。



### 和TLS1.3的比较

#### 消息格式的变化

对比本篇的时序图和前篇的时序图很容易发现部分消息格式发生了变化。下面是`certificateMsg`和`certificateMsgTLS13`的定义：

```go
// TLS1.2
type certificateMsg struct {
	raw          []byte
	certificates [][]byte
}
// TLS1.3
type certificateMsgTLS13 struct {
	raw          []byte
	certificate  tls.Certificate
	ocspStapling bool
	scts         bool
}
```
其他消息的定义笔者就不一一列举了，这里仅列出格式发生变化的消息。

| TLS1.2                | TLS1.3                     |
| :-------------------- | :------------------------- |
| certificateRequestMsg | certificateRequestMsgTLS13 |
| certificateMsg        | certificateMsgTLS13        |



#### 消息类型的变化

TLS1.2和TLS1.3有相同的消息类型也有各自独立的消息类型。下面是笔者例子中TLS1.2和TLS1.3各自独有的消息类型：

| TLS1.2               | TLS1.3                 |
| :------------------- | :--------------------- |
| serverKeyExchangeMsg | -                      |
| clientKeyExchangeMsg | -                      |
| serverHelloDoneMsg   | -                      |
| -                    | encryptedExtensionsMsg |

#### 消息加密的变化

前篇中提到，TLS1.3中除了`clientHelloMsg`和`serverHelloMsg`其他消息均做了加密处理，且握手期间和应用数据使用不同的密钥加密。

TLS1.2中仅有`finishedMsg`做了加密处理，且应用数据也使用该密钥加密。

TLS1.3会计算两次密钥，Client和Server读取对方的`HelloMsg`和`finishedMsg`之后即可计算密钥。

> “Client和Server会各自计算两次密钥，计算时机分别是读取到对方的HelloMsg和finishedMsg之后”，这是前篇中的描述，计算时机描述不准确以上面为准。

TLS1.2只计算一次密钥，Client和Server分别收到`serverKeyExchangeMsg`和`clientKeyExchangeMsg`之后即可计算密钥，和TLS1.3不同的是TLS1.2密钥计算后并不会立即对接下来发送的数据进行加密，只有当发送/接受`ChangeCipherSpec`消息后才会对接下来的数据进行加解密。

#### 生成密钥过程

TLS1.2和TLS1.3生成密钥的过程还是比较相似的， 下图为Client读取`serverKeyExchangeMsg`之后的部分处理逻辑：

![](https://note.youdao.com/yws/api/personal/file/WEB931699839f1e500f2493ca4854c4443e?method=download&shareKey=ffa6348e50fcedca417a2b9b3f3b2c36)

图中`X25519`是椭圆曲线迪菲-赫尔曼（Elliptic-curve Diffie–Hellman ，缩写为ECDH）密钥交换方案之一，这在前篇已经提到过故本篇不再赘述。

根据Debug结果，本例中`ka.preMasterSecret`和TLS1.3中的共享密钥生成逻辑完全一致。不仅如此，在后续的代码分析中，笔者发现TLS1.2也使用了`AEAD`加密算法对数据进行加解密（AEAD在前篇中已经提到过故本篇不再赘述）。 

下图为笔者Debug结果：

![](https://note.youdao.com/yws/api/personal/file/WEB46c9f6e0eebb4d6e53f69bc2715959e1?method=download&shareKey=83cb14cdf13ea7c2968b6f55260741af)

图中`prefixNonceAEAD`即为TLS1.2中AEAD加密算法的一种实现。

这里需要注意的是TLS1.3也会计算`masterSecret`。为了方便理解，我们先回顾一下TLS1.3中生成`masterSecret`的部分源码：

```go
// 基于共享密钥派生hs.handshakeSecret
hs.handshakeSecret = hs.suite.extract(hs.sharedKey,
    hs.suite.deriveSecret(earlySecret, "derived", nil))
// 基于hs.handshakeSecret 派生hs.masterSecret
hs.masterSecret = hs.suite.extract(nil,
	hs.suite.deriveSecret(hs.handshakeSecret, "derived", nil))
```

由上易知，TLS1.3先通过共享密钥派生出`handshakeSecret`，最后通过`handshakeSecret`派生出`masterSecret`。与此相比，TLS1.2生成`masterSecret`仅需一步：

```go
hs.masterSecret = masterFromPreMasterSecret(c.vers, hs.suite, preMasterSecret, hs.hello.random, hs.serverHello.random)
```

`masterFromPreMasterSecret`函数的作用是利用`HMAC`（HMAC在前篇中已经提到故本篇不再赘述）算法对Client和Server的随机数以及共享密钥进行摘要，从而计算得到`masterSecret`。

`masterSecret`在后续的过程中并不会用于数据加密，下面笔者带各位读者分别看一下TLS1.3和TLS1.2生成数据加密密钥的过程。

TLS1.3生成数据加密密钥（以Client计算serverSecret为例）：

```go
serverSecret := hs.suite.deriveSecret(hs.masterSecret,
	serverApplicationTrafficLabel, hs.transcript)
c.in.setTrafficSecret(hs.suite, serverSecret)
```

前篇中提到`hs.suite.deriveSecret`内部会通过`hs.transcript`计算出消息摘要从而重新得到一个`serverSecret`。`setTrafficSecret`方法内部会对`serverSecret`计算得到AEAD加密算法所需要的key和iv（初始向量：Initialization vector）。

因此可知TLS1.3计算密钥和Client/Server生成的随机数无直接关系，而与Client/Server当前收发的所有消息的摘要有关。

> 补充：
> IV通常是随机或者伪随机的。它和数据加密的密钥一起使用可以增加使用字典攻击的攻击者破解密码的难度。例如，如果加密数据中存在重复的序列，则攻击者可以假定消息中相应的序列也是相同的，而IV就是为了防止密文中出现相应的重复序列。
>
> 参考：
>
> https://whatis.techtarget.com/definition/initialization-vector-IV
> https://en.wikipedia.org/wiki/Initialization_vector

TLS1.2生成数据加密密钥：

```go
clientMAC, serverMAC, clientKey, serverKey, clientIV, serverIV :=
			keysFromMasterSecret(tr.vers, suite, p.masterSecret, tr.clientHello.random, tr.serverHello.random, suite.macLen, suite.keyLen, suite.ivLen)
serverCipher = hs.suite.aead(serverKey, serverIV)
c.in.prepareCipherSpec(c.vers, serverCipher, serverHash)
```

前文中提到`masterSecret`的生成与Client和Server的随机数有关，而通过`keysFromMasterSecret`计算AEAD所需的key和iv依旧与随机数有关。

**小结**：

1、本例中TLS1.2和TLS1.3均使用`X25519`算法计算共享密钥。

2、本例中TLS1.2和TLS1.3均使用`AEAD`进行数据加解密。

3、TLS1.3通过共享密钥派生两次才得到`masterSecret`，而TLS1.2以共享密钥、Client和Server的随机数一起计算得到`masterSecret`。

4、TLS1.3通过消息的摘要再次计算得到一个数据加密密钥，而TLS1.2直接通过`masterSecret`计算得到AEAD所需的key和iv。

### TLS1.1和TLS1.0不支持HTTP2

在前面提到本文的例子已经支持解析TLS1.x的握手流程，这个时候笔者突然很好奇浏览器还支持那些版本的TLS协议。

然后笔者在谷歌浏览器上首先测试了TLS1.1的服务，为了方便测试笔者改造了之前[服务器推送的案例]()：

```go
server := &http.Server{Addr: ":8080", Handler: nil}
server.TLSConfig = new(tls.Config)
server.TLSConfig.PreferServerCipherSuites = true
server.TLSConfig.NextProtos = append(server.TLSConfig.NextProtos, "h2", "http/1.1")
// 服务端支持的最大tls版本调整为1.1
server.TLSConfig.MaxVersion = tls.VersionTLS11
server.ListenAndServeTLS("ca.crt", "ca.key")
```
运行Demo后得到如下截图：

![](https://note.youdao.com/yws/api/personal/file/WEB2c8bf091ddf6f390b4a56357eb87fd2f?method=download&shareKey=86fc79ae656452976818c5931a504bf8)

图中红框部分`obsolete`的意思笔者也不知，正好学习一波（技术人的英语大概就是这样慢慢积累起来的吧）。

![](https://note.youdao.com/yws/api/personal/file/WEBab135aec59a8a4c6f59e89b5e1537686?method=download&shareKey=fd9e75e79f9b3cccacfdc54e38e6193f)

这下笔者明白了，TLS1.1已经不被支持所以页面才无法正常访问，然而事实真是如此嘛？

直到几天后笔者开始写这篇文章时，内心仍是十分疑惑，于是使用了`curl`命令再次访问。

![](https://note.youdao.com/yws/api/personal/file/WEB5f9afe2142e28f4f2094daca63d5e17b?method=download&shareKey=51250aff915a34a94c60da68ad7719cf)

图中蓝框部分正是TLS1.1的握手流程，有兴趣的读者可以使用笔者的例子和`curl -v`命令进行双向验证。

图中红框部分提示说“HTTP2的数据发送失败”，笔者才恍然大悟，将上述代码作如下微调后页面可正常访问。

```go
server.TLSConfig.NextProtos = append(server.TLSConfig.NextProtos, "http/1.1")
```

经过笔者的测试，TLS1.0同TLS1.1一样均不支持HTTP2协议，当然这两个协议也不推荐继续使用。

### 写在最后

“纸上得来终觉浅，绝知此事需躬行”。笔者不敢保证把TLS握手流程的每个细节都讲的十分清楚，所以建议各位读者去github克隆代码，然后自己一步一步Debug必然能够加深印象并彻底理解。当然，顺便关注或者star一下这种随手为之的小事，笔者相信各位读者还是十分乐意的～

最后，衷心希望本文能够对各位读者有一定的帮助。

> **注**：
> 1. 写本文时， 笔者所用go版本为: go1.15.2
> 2. 文章中所用完整例子：https://github.com/Isites/go-coder/blob/master/http2/tls/main.go

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)