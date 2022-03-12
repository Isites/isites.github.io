---
title: "用Go构建你专属的JA3指纹"
date: 2022-02-28T08:00:00+08:00
draft: true
toc: true
images:
tags:
  - Go
  - 网络篇
---

在这篇文章中将会简单回顾https的握手流程，并基于读者的提问题解释什么是JA3指纹以及如何用Go定制专属的JA3指纹。

![](https://note.youdao.com/yws/api/personal/file/WEBdd818c0171bf7523dad3029e88986dea?method=download&shareKey=e3b4387645c1dbb41c76b247c1d6bf8d)

本文大纲如下，请各位读者跟着老许的思路逐步构建自己专属的JA3指纹。

![](https://note.youdao.com/yws/api/personal/file/WEBcec2b01408d5c1734f1cc954bf0ad8b1?method=download&shareKey=7121a424f46011dfb6b61242f2b14741)

# 回顾HTTPS握手流程

在正式开始了解什么是JA3指纹之前，我们先回顾一下HTTPS的握手流程，这将有助于对后文的理解。

在[码了2000多行代码就是为了讲清楚TLS握手流程](https://mp.weixin.qq.com/s/TR3Sgkhh2rnlG0DUpyJfvw)这篇文章中主要分析了HTTPS单向认证和双向认证流程(TLS1.3)。

在**单向认证**中，客户端不需要证书，只需验证服务端证书合法即可。其握手流程和交换的msg如下。

![](https://note.youdao.com/yws/api/personal/file/WEBabaa8d21b80ef2e9a69d1b76d1f14306?method=download&shareKey=7b94c83d13c6789208b76e0cba9e974c)

在**双向认证**中，服务端和客户端均需验证对方证书的合法性。其握手流程和交换的msg如下。

![](https://note.youdao.com/yws/api/personal/file/WEB65957ed0aef24f93f20d1e78d9d8b1a2?method=download&shareKey=7894057fa0666f7a9450d2e1ace75ce8)

单向认证和双向认证的对比：

1. 单向认证和双向认证中，总的数据收发仅三次，单次发送的数据中包含一个或者多个消息

2. `clientHelloMsg`和`serverHelloMsg`**未经过加密**，之后发送的消息均做了加密处理

3. Client和Server会各自计算两次密钥，计算时机分别是读取到对方的`HelloMsg`和`finishedMsg`之后

4. 双向认证和单向认证相比，服务端多发送了`certificateRequestMsgTLS13`消息

5. 双向认证和单向认证相比，客户端多发送了`certificateMsgTLS13`和`certificateVerifyMsg`两个消息

无论是单向认证还是双向认证，Server对于Client的基本信息了解完全依赖于Client主动告知Server，而其中比较关键的信息分别是`客户端支持的TLS版本`、`客户端支持的加密套件（cipherSuites）`、`客户端支持的签名算法和客户端支持的密钥交换协议以及其对应的公钥`。这些信息均在包含`clientHelloMsg`中，而这些信息也是生成JA3指纹的关键信息，并且`clientHelloMsg`和`serverHelloMsg`**未经过加密**。未加密意味着修改难度降低，这也就为我们定制自己专属的JA3指纹提供了可能。

> 如果有兴趣了解HTTPS握手流程的更多细节，请阅读下面文章：
> 
> [码了2000多行代码就是为了讲清楚TLS握手流程](https://mp.weixin.qq.com/s/TR3Sgkhh2rnlG0DUpyJfvw)
> 
> [码了2000多行代码就是为了讲清楚TLS握手流程（续）](https://mp.weixin.qq.com/s/ALmouugbrCHrNbyk3OTtSQ)

# 什么是JA3指纹

前面说了这么多，那么到底什么是JA3指纹呢。根据[Open Sourcing JA3](https://engineering.salesforce.com/open-sourcing-ja3-92c9e53c3c41)这篇文章，老许简单将其理解为JA3就是一种在线识别TLS客户端指纹的方法。

该方法用于收集`clientHelloMsg`数据包中以下字段的十进制字节值：`TLS Version`、`Accepted Ciphers`、`List of Extensions`、`Elliptic Curves`和`Elliptic Curve Formats`。然后，它将这些值串联起来，使用“,”来分隔各个字段，同时使用“-”来分隔各个字段中的值。最后，计算这些字符串的md5哈希值，即得到易于使用和共享的长度为32字符的指纹。

为了更近一步描述清楚这些数据的来源，老许将`John Althouse`文章中的抓包图结合Go源码中的`clientHelloMsg`结构体做了字段一一映射。

![](https://note.youdao.com/yws/api/personal/file/WEB1cd179acb8f346061d96229d62c2b533?method=download&shareKey=cfa5647b4b76e8cb9a077520358b848f)

细心的同学可能已经发现了，根据前文描述JA3指纹总共有5个数据字段，而上图却只映射了4个。那是因为TLS的extension字段比较多，老许就不一一整理了。虽然没有一一列举，但老许准备了一个单元测试，有兴趣深入研究的同学可以通过这个单元测试进行调试分析。

```
https://github.com/Isites/go-coder/blob/master/http2/tls/handsh/msg_test.go
```

# JA3指纹用途

根据前文的描述，JA3指纹就是一个md5字符串。请大家回想一下在平时的开发中md5的用途。

* 判断内容是否一致
* 作为唯一标识

> md5虽然不安全，但是JA3选择md5作为哈希的主要原因是为了更好的向后兼容

很明显，JA3指纹也有其类似用途。举个简单的例子，攻击者构建了一个可执行文件，那么该文件的JA3指纹很有可能是唯一的。因此，我们能通过JA3指纹识别出一些恶意软件。

在本小节的最后，老许给大家推荐一个网站，该网站挂出了很多恶意JA3指纹列表。

```
https://sslbl.abuse.ch/ja3-fingerprints/
```

# 构建专属的JA3指纹

## http1.1的专属指纹

前文提到`clientHelloMsg`和`serverHelloMsg`**未经过加密**，这为定制自己专属的JA3指纹提供了可能，而在github上面有一个库(https://github.com/refraction-networking/utls)可以在一定程度上修改`clientHelloMsg`。下面我们将通过这个库构建一个自己专属的JA3指纹。

```go
// 关键import
import (
    xtls "github.com/refraction-networking/utls"
    "crypto/tls"
)

// 克隆一个Transport
tr := http.DefaultTransport.(*http.Transport).Clone()
// 自定义DialTLSContext函数，此函数会用于创建tcp连接和tls握手

tr.DialTLSContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
    dialer := net.Dialer{}
    // 创建tcp连接
    con, err := dialer.DialContext(ctx, network, addr)
    if err != nil {
        return nil, err
    }
    // 根据地址获取host信息
    host, _, err := net.SplitHostPort(addr)
    if err != nil {
        return nil, err
    }
    // 构建tlsconf
    xtlsConf := &xtls.Config{
        ServerName:    host,
        Renegotiation: xtls.RenegotiateNever,
    }
    // 构建tls.UConn
    xtlsConn := xtls.UClient(con, xtlsConf, xtls.HelloCustom)
    clientHelloSpec := &xtls.ClientHelloSpec{
        // hellomsg中的最大最小tls版本
        TLSVersMax: tls.VersionTLS12,
        TLSVersMin: tls.VersionTLS10,
        // ja3指纹需要的CipherSuites
        CipherSuites: []uint16{
            tls.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
            tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
            // tls.TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,
            tls.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,
            tls.TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,
            tls.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,
            tls.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,
            tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
            tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
            // tls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,
            tls.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,
            tls.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,
            tls.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,
            tls.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,
        },
        CompressionMethods: []byte{
            0,
        },
        // ja3指纹需要的Extensions
        Extensions: []xtls.TLSExtension{
            &xtls.RenegotiationInfoExtension{Renegotiation: xtls.RenegotiateOnceAsClient},
            &xtls.SNIExtension{ServerName: host},
            &xtls.UtlsExtendedMasterSecretExtension{},
            &xtls.SignatureAlgorithmsExtension{SupportedSignatureAlgorithms: []xtls.SignatureScheme{
                xtls.ECDSAWithP256AndSHA256,
                xtls.PSSWithSHA256,
                xtls.PKCS1WithSHA256,
                xtls.ECDSAWithP384AndSHA384,
                xtls.ECDSAWithSHA1,
                xtls.PSSWithSHA384,
                xtls.PSSWithSHA384,
                xtls.PKCS1WithSHA384,
                xtls.PSSWithSHA512,
                xtls.PKCS1WithSHA512,
                xtls.PKCS1WithSHA1}},
            &xtls.StatusRequestExtension{},
            &xtls.NPNExtension{},
            &xtls.SCTExtension{},
            &xtls.ALPNExtension{AlpnProtocols: []string{"h2", "http/1.1"}},
            // ja3指纹需要的Elliptic Curve Formats
            &xtls.SupportedPointsExtension{SupportedPoints: []byte{1}}, // uncompressed
            // ja3指纹需要的Elliptic Curves
            &xtls.SupportedCurvesExtension{
                Curves: []xtls.CurveID{
                    xtls.X25519,
                    xtls.CurveP256,
                    xtls.CurveP384,
                    xtls.CurveP521,
                },
            },
        },
    }
    // 定义hellomsg的加密套件等信息
    err = xtlsConn.ApplyPreset(clientHelloSpec)
    if err != nil {
        return nil, err
    }
    // TLS握手
    err = xtlsConn.Handshake()
    if err != nil {
        return nil, err
    }
    fmt.Println("当前请求使用协议：", xtlsConn.HandshakeState.ServerHello.AlpnProtocol)
    return xtlsConn, err
}
```

上述代码总结起来分为三步。

1. 创建TCP连接

2. 构建`clientHelloMsg`需要的信息

3. 完成TLS握手

有了上述代码后，我们通过请求`https://ja3er.com/json`来得到自己的JA3指纹。

```go
c := http.Client{
    Transport: tr,
}
resp, err := c.Get("https://ja3er.com/json")
if err != nil {
    fmt.Println(err)
    return
}
bts, err := ioutil.ReadAll(resp.Body)
resp.Body.Close()
fmt.Println(string(bts), err)
```

最后得到的JA3指纹如下。

![](https://note.youdao.com/yws/api/personal/file/WEBa872c656e9f5dfc1779b2a8670e8215a?method=download&shareKey=56af0f6c9eee594818fe27a4acb5dbc9)

我们已经得到了第一个JA3指纹，这个时候对代码稍加改动以期得到`专属`的JA3指纹。例如我们将`2333`这个数值加入到`CipherSuites`列表中，最后得到结果如下。

![](https://note.youdao.com/yws/api/personal/file/WEB296c40a22832db9ba02150cd2c86b5f6?method=download&shareKey=55ee970405ef9cc315d106275ebc85e5)

最终，JA3指纹又发生了变化，并且可称得上是自己专属的指纹。不用我说，看标题就应该知道问题还没有结束。从前面请求得到JA3指纹的结果图也可以看出来，当前使用的协议为`http1.1`，因此老许从某度中找了一个支持http2的链接继续验证。

![](https://note.youdao.com/yws/api/personal/file/WEBb63489ff37a5bbc9a97bc393f7cd17ad?method=download&shareKey=ab4e6c64f06f2f44693a79222a46b179)

看过[Go发起HTTP2.0请求流程析(前篇)](https://mp.weixin.qq.com/s/TGF9AR5-vaeORVxA2ZFx2A)这篇文章的同学应该知道，http2连接在建立时需要发送`PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n`这么一个字符串。很明显，在自定义了`DialTLSContext`函数之后相关流程缺失。此时，我们该如何构建http2的专属指纹呢？

## http2的专属指纹

通过`DialTLSContext`拨号之后只能得到一个已经完成TLS握手的连接，此时它还不支持http2的`数据帧`、`多路复用`等特性。所以，我们需要自己构建一个支持http2各种特性的连接。

下面，我们通过`golang.org/x/net/http2`来完成自定义TLS握手流程后的http2请求。

```go
// 手动拨号，得到一个已经完成TLS握手后的连接
con, err := tr.DialTLSContext(context.Background(), "tcp", "dss0.bdstatic.com:443")
if err != nil {
    fmt.Println("DialTLSContext", err)
    return
}

// 构建一个http2的连接
tr2 := http2.Transport{}
// 这一步很关键，不可缺失
h2Con, err := tr2.NewClientConn(con)
if err != nil {
    fmt.Println("NewClientConn", err)
    return
}

req, _ := http.NewRequest("GET", "https://dss0.bdstatic.com/5aV1bjqh_Q23odCf/static/superman/img/topnav/newzhidao-da1cf444b0.png", nil)
// 向一个支持http2的链接发起请求并读取请求状态
resp2, err := h2Con.RoundTrip(req)
if err != nil {
    fmt.Println("RoundTrip", err)
    return
}
io.CopyN(io.Discard, resp2.Body, 2<<10)
resp2.Body.Close()
fmt.Println("响应code: ", resp2.StatusCode)
```

结果如下。

![](https://note.youdao.com/yws/api/personal/file/WEB48949c17bf3090c0d16df9cd762d1b59?method=download&shareKey=fe407d3ee11323952bed75edc4f5d584)

可以看到，最终在自定义JA3指纹后，http2的请求也能正常读取。至此，在支持http2的请求中构建专属的JA3指纹就完成了（生成JA3指纹的信息在`clientHelloMsg`中，完成本部分仅是为了确保从发起请求到读取响应都能够正常进行）。

额外补充几句，通过手动`NewClientConn`这种方式完成http2请求具有很大的局限性。比如，需要自己管理连接的生命周期、无法自动重连等。当然，这些都是后话，真有这方面需求的时候，可能就需要开发者从go源码将net包fork一份自己维护了。

# 写在最后

老许写下本文不仅仅是带大家了解ja3，更多的是期望各位读者能够通过自身的实践加深对http底层的理解。

最后，衷心希望本文能够对各位读者有一定的帮助。

> 注：
> 
> 写本文时， 笔者所用go版本为: go1.17.7
> 
> 文章中所用完整例子：https://github.com/Isites/go-coder/blob/master/http2/ja3/main.go

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)