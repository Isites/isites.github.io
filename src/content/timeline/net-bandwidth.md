---
title: "一次带宽拉满引发的百分百超时血案！"
date: 2021-09-05T12:20:38+08:00
draft: true
toc: true
images:
tags:
  - Go
---



**偈语**: 未经他人苦,莫劝他人善


鏖战两周有余，为了排查线上某接口百分百超时的原因，如今总算有些成果。虽然仍有疑虑但是碍于时间不允许和个人能力问题先做如下总结以备来日再战。

# 出口带宽拉满

能够发现这个问题实属侥幸。依稀记得这是一个风雨交加的夜晚，这风、这雨注定了今夜的不平凡。果然线上百分百超时的根因被发现了！

![](https://note.youdao.com/yws/api/personal/file/WEBd5b061984272ce237fa1e49f9090991c?method=download&shareKey=097a49e398b431f0231fc25ab2b106f3)

我们的线上接口需要对外请求，而我们的流出带宽被拉满自然耗时就长因此导致超时。当然这都是结果，毕竟中间过程的艰辛已经远远超出老许的文字所能描述的范围。


## 反思

结果有了，该有的反思仍旧不能少。比如流出带宽被拉满为什么没有提前预警！无论是自信带宽足够还是经验不足都值得老许记上一笔。

而在带宽问题被真正发现之前，老许内心对带宽其实已有所怀疑，但是却没有认真进行验证，只听信了他人的推测导致发现问题的时间被推迟。


## httptrace

有时候不得不吹一波Go对http trace的良好支持。老许也是基于此做了一个demo，该demo可以打印http请求各阶段耗时。

![](https://note.youdao.com/yws/api/personal/file/WEBae017d707ebfecab6294e99b2521ee75?method=download&shareKey=ae68fed9224c9b0afe62d72b023f29ae)

上述为一次http请求各阶段耗时输出，有兴趣的可去https://github.com/Isites/go-coder/blob/master/httptrace/trace.go拿到源码。

>老许对带宽的怀疑主要就是基于此demo中的源码进行线上分析测试给到的推测。


# 框架问题
本部分更加适合腾讯系的兄弟们去阅读，其他非腾讯系技术可以直接跳过。

我司的框架为TarsGo，我们在线上设置`handletimeout`为1500ms，该参数主要用于控制某一接口总耗时不超过1500ms，而我们的超时告警均为3s，因此即使带宽已满这个百分百超时告警也不应出现。

为了研究这个原因，老许只好花些零碎的时间去阅读源码，最终发现了`TarsGo@v1.1.6`的`handletimeout`控制是无效的。

下面看一下有问题的源码:

```go
func (s *TarsProtocol) InvokeTimeout(pkg []byte) []byte {
	rspPackage := requestf.ResponsePacket{}
	rspPackage.IRet = 1
	rspPackage.SResultDesc = "server invoke timeout"
	return s.rsp2Byte(&rspPackage)
}
```
当某接口总执行时间超过`handletimeout`时，会调用`InvokeTimeout`方法告知client调用超时，而上述的逻辑中忽略了`IRequestId`的响应，这就导致client收到响应包时无法将响应包和某次的请求对应起来，从而导致客户端一直等待响应直至超时。

最终修改如下：

```go
func (s *TarsProtocol) InvokeTimeout(pkg []byte) []byte {
	rspPackage := requestf.ResponsePacket{}
	//  invoketimeout need to return IRequestId
	reqPackage := requestf.RequestPacket{}
	is := codec.NewReader(pkg[4:])
	reqPackage.ReadFrom(is)
	rspPackage.IRequestId = reqPackage.IRequestId
	rspPackage.IRet = 1
	rspPackage.SResultDesc = "server invoke timeout"
	return s.rsp2Byte(&rspPackage)
}
```

后来老许在本地用demo验证`handletimeout`终于可以控制生效。当然本次修改老许已经在github上面提交issue和pr，目前已被合入master。相关issue和pr如下：

https://github.com/TarsCloud/TarsGo/issues/294

https://github.com/TarsCloud/TarsGo/pull/295

# 仍有疑虑

到这里，事情依然没有得到完美的解决。

![](https://note.youdao.com/yws/api/personal/file/WEB72c46f05419d673285f86cec37ea4007?method=download&shareKey=6df9055ae9a95a8053359ca0230a904b)

上图为我们对外部请求做的最大耗时统计，毛刺严重且耗时简直不符合常理。图中标红部分耗时约为881秒，而实际上我们在发起http请求时均做了严格的超时控制，这也是令老许最为头疼的问题，这几天脸上冒的痘都是为它熬夜的证明。

更加令人惊恐的事情是，我们将官方的`http`替换为`fasthttp`后，毛刺没有了！老许自认为对go的http源码还有几分浅薄的理解，而残酷的现实简直令人怀疑人生。

到目前，老许再次简阅了一遍http的源码，仍未发现问题，这大概率会成为一桩悬案了，还望各位有经验的大佬分享一二，至少让这篇文章有始有终。

> 替换fasthttp时还未发现带宽被拉满

# 美好愿景

最后，别无他言，直接上图！


![](https://note.youdao.com/yws/api/personal/file/WEBb0b4bfb20ebd27b75169412e18e6fb30?method=download&shareKey=8b7089fb9546f78e5074095ca7175a7c)


【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)