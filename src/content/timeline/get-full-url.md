---
title: "有趣！一行代码居然无法获取请求的完整URL"
date: 2021-03-29T19:36:38+08:00
draft: true
toc: true
images:
tags:
  - Go
  - 网络篇
---


## 缘起

做Web服务的时候，可能会有这样一个业务场景，获取一个HTTP请求的完整URL。很巧，老许就碰到了这样的业务场景。面对如此简单的需求，CV大法根本没有展示才能的机会。啪啪啪，获取请求的完整URL代码就出来了。

![](https://note.youdao.com/yws/api/personal/file/WEB1b388f6771a1db510b40ef8a8d5eebae?method=download&shareKey=9cb4b3dffe79b0a2eaa385a09947d7a6)

当时离验证只差一步，老许信心满满，很快，打脸来得很快就像龙卷风。。。

![](https://note.youdao.com/yws/api/personal/file/WEB996f7f766dd31e910911a18f8b86fa44?method=download&shareKey=25f35485c3812f561c3da580916f7f4d)

从图中可以知道，`req.URL`中的`Scheme`和`Host`均为空，所以`r.URL.String()`无法得到完整的请求连接。这个结果让老许一阵激动，万万没想到有一天我也有机会发现Go源码中可能遗漏的赋值。老许强行按耐住心中的激动，准备好好研究一番，万一成为了Go的Contributor呢\^ω\^。最后发现官方实现没有问题，因此就有了今天这篇文章。

## HTTP1.1中为什么无法获取完整的连接

HTTP1.1的Server读取请求并构建`Request.URL`对象的逻辑在request.go文件的`readRequest`方法中，下面老许对其源码做一个简单分析总结。

1. 读取请求的第一行，HTTP请求的第一行又称为请求行。

```go
// First line: GET /index.html HTTP/1.0
var s string
if s, err = tp.ReadLine(); err != nil {
	return nil, err
}
```

2. 将请求行的内容分别解析为`req.Method`、`req.RequestURI`和`req.Proto`。


```go
var ok bool
req.Method, req.RequestURI, req.Proto, ok = parseRequestLine(s)
```

3. 将`req.RequestURI`解析为`req.URL`。

```go
rawurl := req.RequestURI
if req.URL, err = url.ParseRequestURI(rawurl); err != nil {
	return nil, err
}
```

> 注：当请求方法是CONNECT时，上述流程略有变化

通过上面的流程我们知道`req.URL`的数据来源为`req.RequestURI`，而`req.RequestURI`到底是什么让我们继续阅读后文。

### 请求资源

根据rfc7230中的定义， 请求行分为请求方法、请求资源和HTTP版本，分别对应上述的`req.Method`、`req.RequestURI`和`req.Proto`（request-target在本文均被译作请求资源）。

![](https://note.youdao.com/yws/api/personal/file/WEB8fcef32e2e58798269cc3809e45c75c4?method=download&shareKey=5b2a53ff2aff6ebbed544e692d92c85d)

关于请求方法有哪些想必不用老许在这儿科普了吧。至于常用的HTTP版本无非就是HTTP1.1和HTTP2。 下面主要介绍请求资源的几种形式。

#### origin-form

这种形式是请求资源中最常见的形式，其格式定义如下。

```
origin-form    = absolute-path [ "?" query ]
```

当直接向服务器发起请求时，除开CONNECT和OPTIONS请求，只允许发送path和query作为请求资源。如果请求链接的path为空，则必须发送`/`作为请求资源。请求链接中的Host信息以Header头的形式发送。

以`http://www.example.org/where?q=now`为例，请求行和Host请求头信息如下

```
GET /where?q=now HTTP/1.1
Host: www.example.org
```
#### absolute-form

这种形式目前仅在向代理发起请求时使用，其格式定义如下。

```
absolute-form  = absolute-URI
```

根据rfc7230中的定义，目前client仅会向代理发送这种形式的请求资源，但为了将来某个HTTP版本可能会转换为这种形式的请求资源所以server需要支持这种形式的请求资源。这大概就是为什么`req.URL`中大部分字段值为空却仍然将URL各部分定义完整的原因。

一个`absolute-form`形式的请求行例子如下。
```
GET http://www.example.org/pub/WWW/TheProject.html HTTP/1.1
```

#### authority-form

`authority-form`形式的请求资源仅用于`CONNECT`请求中，其格式定义如下。

```
authority-form = authority
```
发送`CONNECT`请求时，client只能发送URI的authority部分（不包含userinfo和@定界符）作为请求资源。这样讲比较抽象， 我们先来看看`http-URI`的定义。

![](https://note.youdao.com/yws/api/personal/file/WEB9a1f70183935d70850b51956403b3d96?method=download&shareKey=34a7404d25c494cd9c889216ed50819e)

通过上面这张图大概能够猜出来`authority`应该是指Host信息。Very Good！你没有猜错！

```
The origin server for an "http" URI is identified by the authority component, which includes a host identifier and optional TCP port.
```
上面是rfc7230对于authority的解释。老许根据自己的翻译，在这里单方面宣布`authority`包括主机标识符和可选的端口信息。一个`authority-form`形式的请求行例子如下。

```
CONNECT www.example.com:80 HTTP/1.1
```

#### asterisk-form

`asterisk-form`形式的请求资源仅适用于`OPTIONS`请求且只能为`*`，其格式定义如下。

```
asterisk-form  = "*"
```
一个`asterisk-form`形式的请求行例子如下。

```
OPTIONS * HTTP/1.1
```

对上面几种形式的请求资源有所了解后，我们再次回到获取请求的完整URL这一问题本身。以最常用的`absolute-form`为例（其他形式的请求资源我们在开发中几乎不用考虑），请求资源中本身就缺少`Host`和`Scheme`信息，所以一行代码自然无法获取请求的完整URL。难道我们就无法获取到请求的完整URL嘛？当然不是，我们还可以通过以下两种方案得到完整的URL。

**方案一**：
1. 通过`req.Host`得到Host相关信息。
2. 如果`req.TLS == nil`则为HTTP请求，否则为HTTPS请求。
3. 通过步骤1、步骤2并结合请求行信息即可得到完整的URL。


**方案二**：
在配置文件中配置好服务的Host信息，获取完整请求时只需要读取配置文件并拼接`req.RequestURI`即可。事实上老许采用的就是方案二，因为很多服务都在网关后面。当客户端使用HTTPS请求网关，网关以HTTP请求服务时使用`req.TLS == nil`判断就不合理了。

## HTTP2中为什么无法获取完整的连接

需要注意的是在HTTP2中已经没有请求行的概念了，取而代之的是请求伪标头，这一点老许在[Go发起HTTP2.0请求流程分析(后篇)——标头压缩](https://mp.weixin.qq.com/s/HTGg5HYRSVY-4-H9Sf1zww)这篇文章中提到过。

下图为一次HTTP2请求的部分Header信息。

![](https://note.youdao.com/yws/api/personal/file/WEB21b6c46dfb68ab42e0f5f00830a3cda5?method=download&shareKey=444b90bc7502a0befde80ba2a08ae545)

从图中可以发现，HTTP1.1中的请求行已经没有了。根据rfc7540中的定义，请求的伪标头字段有`:method`、`:scheme`、`:authority`和`:path`。

`:method`和`:scheme`不需要老许多说，看英文单词的意思就可以了。

`:authority`: 根据前文的解释，其值为主机标识符和可选的端口信息。另外需要注意的是HTTP2中没有`Host`请求头。

`:path`: 如果是`OPTIONS`请求，则其值为`*`。其他情况该值为请求URI的path和query，如果path为空则其值为`/`。

在对HTTP2请求的伪标头有了一个基本了解后，下面我们来看一下`Request.URL`的赋值过程。HTTP2的Server读取请求并构建`Request.URL`对象的逻辑在h2_bundle.go文件的`(*http2serverConn).newWriterAndRequestNoBody`方法中。

1. 如果是`CONNECT`请求通过`:authority`构建`url_`，否则通过`:path`构建`url_`。


```go
if rp.method == "CONNECT" {
	url_ = &url.URL{Host: rp.authority}
	requestURI = rp.authority // mimic HTTP/1 server behavior
} else {
	var err error
	url_, err = url.ParseRequestURI(rp.path)
	if err != nil {
		return nil, nil, http2streamError(st.id, http2ErrCodeProtocol)
	}
	requestURI = rp.path
}
```

2. 将`url_`赋值给`req.URL`。

```go
req := &Request{
	Method:     rp.method,
	URL:        url_,
	RemoteAddr: sc.remoteAddrStr,
	Header:     rp.header,
	RequestURI: requestURI,
	Proto:      "HTTP/2.0",
	ProtoMajor: 2,
	ProtoMinor: 0,
	TLS:        tlsState,
	Host:       rp.authority,
	Body:       body,
	Trailer:    trailer,
}
```
由于`:path`标头的值也不包含Host信息，所以HTTP2的server也无法通过`req.URL.String()`得到请求的完整URL。

在这里我们反思一个问题。通过伪标头字段已经能够得到完整的URL，为什么仍然只读取`:path`和`:authority`中的一个来赋值`req.URL`呢？

老许在这里猜测可能原因是希望开发者无需关心请求是HTTP1.1还是HTTP2，避免不必要的HTTP版本判断。

关于获取请求完整URL的思考就到这里。最后，衷心希望本文能够对各位读者有一定的帮助。


> **注**：
>
> 1. 写本文时， 笔者所用go版本为: go1.15.2


参考：

https://tools.ietf.org/html/rfc7230

https://tools.ietf.org/html/rfc7540


【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)