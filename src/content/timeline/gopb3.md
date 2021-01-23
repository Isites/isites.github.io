---
title: "区分Protobuf 3中缺失值和默认值"
date: 2020-12-01T12:20:38+08:00
draft: true
toc: true
images:
tags:
  - Go
---

这两天翻了翻以前的项目，发现不同项目中关于Protobuf 3缺失值和默认值的区分居然有好几种实现。今天笔者冷饭新炒，结合项目中的实现以及切身经验共总结出如下六种方案。

### 增加标识字段

众所周知，在Go中数字类型的默认值为`0`（这里仅以数字类型举例），这在某些场景下往往会引起一定的歧义。

> 以`is_show`字段为例，如果没有该字段表示不更新DB中的数据，如果有该字段且值为`0`则表示更新DB中的数据为不可见，如果有该字段且值为`1`则表示更新DB中的数据为可见。

上述场景中，实际要解决的问题是如何区分默认值和缺失字段。增加标识字段是通过额外增加一个字段来达到区分的目的。

例如：增加一个`has_show_field`字段标识`is_show`是否为有效值。如果`has_show_field`为`true`则`is_show`为有效值，否则认为`is_show`未设置值。

此方案虽然直白，但每次设置`is_show`的值时还需设置`has_show_field`的值，甚是麻烦故笔者十分不推荐。

### 字段含义和默认值区分

字段含义和默认值区分即不使用对应类型的默认值作为该字段的有效值。接着前面的例子继续描述，`is_show`为1时表示展示，`is_show`为2时表示不展示，其他情况则认为`is_show`未设置值。

此方案笔者还是比较认可的，唯一问题就是和开发者的默认习惯略微不符。

### 使用oneof

oneof 的用意是达到 C 语言 union 数据类型的效果，但是诸多大佬还是发现它可以标识缺失字段。

```go
message Status {
  oneof show {
    int32 is_show = 1;
  }
}
message Test {
    int32 bar = 1;
    Status st = 2;
}
```

上述proto文件生成对应go文件后，`Test.St`为`Status`的指针类型，故通过此方案可以区分默认值和缺失字段。但是笔者认为此方案做json序列化时十分不友好，下面是笔者的例子：

```go
// oneof to json
ot1 := oneof.Test{
  Bar: 1,
  St: &oneof.Status{
    Show: &oneof.Status_IsShow{
      IsShow: 1,
    },
  },
}
bts, err := json.Marshal(ot1)
fmt.Println(string(bts), err)
// json to oneof failed
jsonStr := `{"bar":1,"st":{"Show":{"is_show":1}}}`
var ot2 oneof.Test
fmt.Println(json.Unmarshal([]byte(jsonStr), &ot2))
```

上述输出结果如下：

```
{"bar":1,"st":{"Show":{"is_show":1}}} <nil>
json: cannot unmarshal object into Go struct field Status.st.Show of type oneof.isStatus_Show
```

通过上述输出知，oneof的`json.Marshal`输出结果会额外多一层，而`json.Unmarshal`还会失败，因此使用oneof时需谨慎。

### 使用wrapper类型

这应该是google官方提出的解决方案，我们看看下面的例子：

```go
import "google/protobuf/wrappers.proto";
message Status {
    google.protobuf.Int32Value is_show = 1;
}
message Test {
    int32 bar = 1;
    Status st = 2;
}
```

使用此方案需要引入`google/protobuf/wrappers.proto`。此方案生成对应go文件后，`Test.St`也是`Status`的指针类型。同样，我们也看一下它的json序列化效果：

```go
wra1 := wrapper.Test{
  Bar: 1,
  St: &wrapper.Status{
    IsShow: wrapperspb.Int32(1),
  },
}
bts, err = json.Marshal(wra1)
fmt.Println(string(bts), err)
jsonStr = `{"bar":1,"st":{"is_show":{"value":1}}}`
// 可正常转json
var wra2 wrapper.Test
fmt.Println(json.Unmarshal([]byte(jsonStr), &wra2))
```

上述输出结果如下：

```
{"bar":1,"st":{"is_show":{"value":1}}} <nil>
<nil>
```

和oneof方案相比wrapper方案的json反序列化是没问题的，但是`json.Marshal`的输出结果也会额外多一层。另外，经笔者在本地试验，此方案无法和`gogoproto`一起使用。

###  允许proto3使用`optional`标签

前面几个方案估计在实践中还是不够尽善尽美。于是2020年5月16日`protoc v3.12.0`发布，该编译器允许proto3的字段也可使用 `optional`修饰。

下面看看例子：

```go
message Status {
  optional int32 is_show = 1;
}
message Test {
    int32 bar = 1;
    Status st = 2;
}
```

此方案需要使用新版本的`protoc`且必须使用`--experimental_allow_proto3_optional`开启此特性。protoc升级教程见https://github.com/protocolbuffers/protobuf#protocol-compiler-installation。下面继续看看该方案的json序列化效果

```go
var isShow int32 = 1
p3o1 := p3optional.Test{
  Bar: 1,
  St:  &p3optional.Status{IsShow: &isShow},
}
bts, err = json.Marshal(p3o1)
fmt.Println(string(bts), err)
var p3o2 p3optional.Test
jsonStr = `{"bar":1,"st":{"is_show":1}}`
fmt.Println(json.Unmarshal([]byte(jsonStr), &p3o2))
```

上述输出结果如下：

```
{"bar":1,"st":{"is_show":1}} <nil>
<nil>
```

据上述结果知，此方案与oneof以及wrapper方案的json序列化相比更加符合预期，同样，经笔者在本地试验，此方案无法和`gogoproto`一起使用。

### proto2和proto3结合使用

作为一个`gogoproto`的忠实用户，笔者希望在能区分默认值和缺失值的同时还可以继续使用`gogoproto`的特性。于是便产生了proto2和proto3结合使用的野路子。

```go
// proto2
message Status {
    optional int32 is_show = 2;
}
// proto3
message Test {
    int32 bar = 1 [(gogoproto.moretags) = 'form:"more_bar"', (gogoproto.jsontag) = 'custom_tag'];
    p3p2.Status st = 2;
}
```

需要区分缺失字段和默认值的message定义在语法为proto2的文件中，proto3通过`import`导入proto2的message以达区分目的。

`optional`修饰的字段在Go中会生成指针类型，因此区分缺失值和默认值就变的十分容易了。下面看看此方案的json序列化效果：

```go
// p3p2 to json
p3p21 := p3p2.Test{
  Bar: 1,
  St:  &p3p2.Status{IsShow: &isShow},
}
bts, err = json.Marshal(p3p21)
fmt.Println(string(bts), err)
var p3p22 p3p2.Test
jsonStr = `{"custom_tag":1,"st":{"is_show":1}}`
fmt.Println(json.Unmarshal([]byte(jsonStr), &p3p22))
```

上述输出结果如下：

```
{"custom_tag":1,"st":{"is_show":1}} <nil>
<nil>
```

根据上述结果知，此方案不仅能够活用`gogoproto`的各种tag，其结果也和**在proto3中直接使用optional**效果一致。虽然笔者已经在自己的项目中使用了此方案，但是仍然要提醒一句：“写本篇文章时，笔者特意去github看了gogoproto的发布日志，gogoproto最新一个版本发布时间为`2019年10月14日`，笔者大胆预言gogoproto以后不会再更新了，所以此方案还请大家酌情使用”。

最后，衷心希望本文能够对各位读者有一定的帮助。

> 注：
> 1. 文中笔者所用go版本为：go1.15.2
> 2. 文中笔者所用protoc版本为：3.14.0
> 3. 文章中所用完整例子：https://github.com/Isites/go-coder/blob/master/pbjson/main.go




【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)