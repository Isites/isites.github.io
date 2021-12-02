---
title: "终于解决了这个线上偶现的panic问题"
date: 2021-11-23T12:20:38+08:00
draft: true
toc: true
images:
tags:
  - Go
---



不知道其他人是不是这样，反正老许最怕听到的词就是“偶现”，至于原因我不多说，懂的都懂。

下面直接看`panic`信息。

```
runtime error: invalid memory address or nil pointer dereference

panic(0xbd1c80, 0x1271710)
        /root/.go/src/runtime/panic.go:969 +0x175
github.com/json-iterator/go.(*Stream).WriteStringWithHTMLEscaped(0xc00b0c6000, 0x0, 0x24)
        /go/pkg/mod/github.com/json-iterator/go@v1.1.11/stream_str.go:227 +0x7b
github.com/json-iterator/go.(*htmlEscapedStringEncoder).Encode(0x12b9250, 0xc0096c4c00, 0xc00b0c6000)
        /go/pkg/mod/github.com/json-iterator/go@v1.1.11/config.go:263 +0x45
github.com/json-iterator/go.(*structFieldEncoder).Encode(0xc002e9c8d0, 0xc0096c4c00, 0xc00b0c6000)
        /go/pkg/mod/github.com/json-iterator/go@v1.1.11/reflect_struct_encoder.go:110 +0x78
github.com/json-iterator/go.(*structEncoder).Encode(0xc002e9c9c0, 0xc0096c4c00, 0xc00b0c6000)
        /go/pkg/mod/github.com/json-iterator/go@v1.1.11/reflect_struct_encoder.go:158 +0x3f4
github.com/json-iterator/go.(*structFieldEncoder).Encode(0xc002eac990, 0xc0096c4c00, 0xc00b0c6000)
        /go/pkg/mod/github.com/json-iterator/go@v1.1.11/reflect_struct_encoder.go:110 +0x78
github.com/json-iterator/go.(*structEncoder).Encode(0xc002eacba0, 0xc0096c4c00, 0xc00b0c6000)
        /go/pkg/mod/github.com/json-iterator/go@v1.1.11/reflect_struct_encoder.go:158 +0x3f4
github.com/json-iterator/go.(*OptionalEncoder).Encode(0xc002e9f570, 0xc006b18b38, 0xc00b0c6000)
        /go/pkg/mod/github.com/json-iterator/go@v1.1.11/reflect_optional.go:70 +0xf4
github.com/json-iterator/go.(*onePtrEncoder).Encode(0xc002e9f580, 0xc0096c4c00, 0xc00b0c6000)
        /go/pkg/mod/github.com/json-iterator/go@v1.1.11/reflect.go:219 +0x68
github.com/json-iterator/go.(*Stream).WriteVal(0xc00b0c6000, 0xb78d60, 0xc0096c4c00)
        /go/pkg/mod/github.com/json-iterator/go@v1.1.11/reflect.go:98 +0x150
github.com/json-iterator/go.(*frozenConfig).Marshal(0xc00012c640, 0xb78d60, 0xc0096c4c00, 0x0, 0x0, 0x0, 0x0, 0x0)
```

首先我坚信一条，开源的力量值得信赖。因此老许第一波操作就是，分析业务代码是否有逻辑漏洞。很明显，同事也是值得信赖的，因此果断猜测是某些未曾设想到的数据触发了边界条件。接下来就是保存现场的常规操作。

![](https://note.youdao.com/yws/api/personal/file/WEB55378a70dcf723b1617068ca71946b42?method=download&shareKey=8271f11fe3137da9849495f3fe9f899e)


如标题所说，这是偶现的panic问题，因此按照上面的分类采用符合当前技术栈的方法保存现场即可。接下来就是坐等收获的季节，而这一等就是好多天。中间数次收到告警，却没有符合预期的现场。

这个时候我不仅不慌，甚至还有点小激动。某某曾曰：“要敢于质疑，敢于挑战权威”，一念至此便一发不可收拾，我老许又要为开源事业做出贡献了嘛！说干就敢干，怀着小心思开始阅读`json-iterator`的源码。

刚开始研读我便明白了一个道理， “当上帝关了这扇门，一定会为你打开另一扇门”这句话是骗人的。老许只觉得上帝不仅关上了所有的门甚至还关上了所有的窗。下面我们看看他到底是怎么关门的。

```go
func (cfg *frozenConfig) Marshal(v interface{}) ([]byte, error) {
	stream := cfg.BorrowStream(nil)
	defer cfg.ReturnStream(stream)
	stream.WriteVal(v)
	if stream.Error != nil {
		return nil, stream.Error
	}
	result := stream.Buffer()
	copied := make([]byte, len(result))
	copy(copied, result)
	return copied, nil
}


// WriteVal copy the go interface into underlying JSON, same as json.Marshal
func (stream *Stream) WriteVal(val interface{}) {
	if nil == val {
		stream.WriteNil()
		return
	}
	// 省略其他代码
}

```

根据panic栈知道是因为空指针造成了panic，而`(*frozenConfig).Marshal`函数内部已经做了非空判断。到此，老许真的已经别无他法只得战略性放弃解决此次panic。毕竟，这个影响也没那么大，而且程序员哪有修的完的bug呢。经过这样一番安慰，心里确实容易接受多了。

事实上，在较长一段时间内我都有意识地忽略这个问题，毕竟没有找到问题的根因。这个问题在线上一直持续到一个说不上来什么日子的日子，总而言之就是兴致来了，我再次看了两眼，而这两眼很关键！

```go
func doReq() {
    req := paramsPool.Get().(*model.Params)
    // defer 1
    defer func() {
    	reqBytes, _ := json.Marshal(req)
    	// 省略其他打印日志的代码
    }()
    // defer 2
    defer paramsPool.Put(req)
    // req初始化以及发起请求和其他操作
}
```

> **注：**
>
> 1. 上述代码变量命名已经被老许通用化处理。
> 2. 项目中实际代码远比上述复杂，但上述代码依旧是造成本次问题的最小原型。

上面代码中`paramsPool`是`sync.Pool`类型的变量，而`sync.Pool`想必大家都很熟悉。`sync.Pool`是为了复用已经使用过的对象(协程安全)，减少内存分配和降低GC压力。
```go
type test struct {
	a string
}

var sp = sync.Pool{
	New: func() interface{} {
		return new(test)
	},
}

func main() {
	t := sp.Get().(*test)
	fmt.Println(unsafe.Pointer(t))
	sp.Put(t)
	t1 := sp.Get().(*test)
	t2 := sp.Get().(*test)
	fmt.Println(unsafe.Pointer(t1), unsafe.Pointer(t2))
}
```

![](https://note.youdao.com/yws/api/personal/file/WEB30a2f5c4b11b2974a9dacfaa7afc06a8?method=download&shareKey=c81b700ce8b721b4d27062c5f07ef4e3)

根据上述代码和输出结果知，`t1`变量和`t`变量地址一致，因此他们是复用对象。此时再回顾上面的`doReq`函数就很容易发现问题的根因。

`defer 2`和`defer 1`顺序反了！！！

`defer 2`和`defer 1`顺序反了！！！

`defer 2`和`defer 1`顺序反了！！！

`sync.Pool`提供的`Get`和`Put`方法是协程安全的，但是高并发调用`doReq`函数时`json.Marshal(req)`和请求初始化会存在并发问题，极有可能引起panic的并发调用时间线如下图所示。

![](https://note.youdao.com/yws/api/personal/file/WEBab9220ec9c5c75ac59489fd69039e269?method=download&shareKey=e962344375d221450b80e4b1d6306aec)

既然已经找到原因，解决起来就容易多了，只需调整`defer 2`和`defer 1`的调用顺序即可。老许将修改后的代码发布到线上后也确实再没有出现panic。造成这次事故的根本原因是一个微乎其微的细节，所以我们平时在开发中还是要谨慎加谨慎，避免因为这种小白错误造成不可挽回的损失。另外一个经验之谈就是，开发和查问题时尽量不要钻牛角尖，适当的停顿可能会有意想不到的奇效。

最后，衷心希望本文能够对各位读者有一定的帮助。

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)