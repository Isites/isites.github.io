---
title: "除以零不会panic？"
date: 2022-03-08T08:48:00+08:00
draft: true
toc: true
images:
tags:
  - Go
---

有常识的人都知道，在除法运算中不能除以零，而我们在实际的应用中面对大量的上下文，很有可能因为考虑不周就出现除以零的情况。因此，我们有必要知道除以零到底会不会panic？如果不发生panic，又会得到什么样的值？

下面，我们带着这样的疑问继续阅读本文。相信在读完本文后，这两个疑问会烟消云散。同时，为了能够让读者快速地了解本文的全貌，下面列出本文的大纲。

![](https://note.youdao.com/yws/api/personal/file/WEB5718c1e79d725e9f8b6f9ebab3e0b5c9?method=download&shareKey=99056d16a9d584fdb1da2c0f238c8ff0)

## 除以零值

在Go中，可能除以零的情况分为三种，分别是除以常量`0`、整形`0`和浮点数`0`。下面我们分别看一下这三种情况的实际表现。

### 除以常量0

![](https://note.youdao.com/yws/api/personal/file/WEBda6ad1b2f12eb383ac4c7586800acd7c?method=download&shareKey=c427b280fd6acb79572bce4b75534825)

根据上图知道，除以常量0是无法编译通过的。这一点，还是比较令人安心。

### 除以整形0

![](https://note.youdao.com/yws/api/personal/file/WEBe2ebdbd291cf28a74e5679d086ce5741?method=download&shareKey=2692f8421bd841e780f4c163cf7017da)

根据上图知，除以整形0会发生panic。这一点，在平时的开发中还需格外注意。

### 除以浮点数0

除以浮点数0，情况会略微复杂。请看下代码和输出结果。

```go
var zero = float64(0)
fmt.Println(1024 / zero) // 输出：+Inf
fmt.Println(-1024 / zero) // 输出：-Inf
fmt.Println(0 / zero) // NaN
```

上面输出中`Inf`为单词`infinity`的缩写，该单词含义为无穷，因此`+Inf`和`-Inf`分别表示正无穷和负无穷。

`NaN`意味着`not a number`，即结果不是一个数。

到这里，老许不得不感叹浮点数确实博大精深，在Go里面除以0确实不会panic（经过老许验证，在python里面会发生错误）。另外，上述中`0/zero`得到`NaN`，而整形中0除以0依旧会panic。

## ±Inf值

### 判断是否是±Inf

前面通过正数和负数分别除以浮点数0可到正无穷和负无穷。Go里面`math`包提供的`Inf`函数也可以得到正无穷和负无穷，同时还提供了`IsInf`函数用于判断是正无穷还是负无穷。

`math.Inf`函数签名为`func(int) float64`，当传入的参数大于等于0时返回正无穷，否则返回负无穷。

`math.IsInf`函数签名为`func(float64, int) bool`，第一个参数为待判断的值，第二个参数大于0时，返回第一个参数是否为正无穷，第二个参数小于0时，返回第一个参数是否为负无穷，第二个参数等于0时，返回第一个参数是否为无穷。

具体验证，请看下面代码和输出。

```go
positiveInf := math.Inf(1)
negativeInf := math.Inf(-1)
// 判断是否为正无穷
fmt.Println(math.IsInf(positiveInf, 1)) // 输出：true
// 判断是否为负无穷
fmt.Println(math.IsInf(negativeInf, 1)) // 输出：false
// 判断是否为正无穷
fmt.Println(math.IsInf(positiveInf, -1)) // 输出：false
// 判断是否为负无穷
fmt.Println(math.IsInf(negativeInf, -1)) // 输出：true
// 判断是否为无穷
fmt.Println(math.IsInf(positiveInf, 0)) // 输出：true
// 判断是否为无穷
fmt.Println(math.IsInf(negativeInf, 0)) // 输出：true
// 判断是否为无穷
fmt.Println(math.IsInf(1024, 0)) // 输出：false
```

### ±Inf的比较

正无穷和负无穷输出结果和我们平时看到数值类型迥然不同，而且也无法直接将`±Inf`直接赋值给一个浮点类型的变量，那么他们是否可以参与数值之间的比较呢，请看下面代码和输出。

```go
positiveInf := math.Inf(1)
negativeInf := math.Inf(-1)
// 判断正无穷是否可以和自身比较
fmt.Println(positiveInf == positiveInf) // 输出：true
// 判断负无穷是否可以和自身比较
fmt.Println(negativeInf == negativeInf) // 输出：true
// 判断正无穷是否大于正数
fmt.Println(positiveInf > math.MaxFloat64) // 输出：true
// 判断负无穷是否小于正数
fmt.Println(negativeInf < -math.MaxFloat64) // 输出：true
```

根据输出结果知，正负无穷可以比较，且表示的值确实暗合无穷这一数学意义。

## NaN值

### 判断是否是NaN

在这里加深一下生成`NaN`值的印象，浮点数零相除即可得到`NaN`值。同样，`math`包提供了`NaN`函数和`IsNaN`函数分别用于返回一个`NaN`值和判断一个浮点数是否为`NaN`。

请看下面代码和输出。

```go
nan := math.NaN()
fmt.Println(math.IsNaN(nan))  // 输出：true
fmt.Println(math.IsNaN(10.2)) // 输出：false
```

其他可生成NaN值的情况：

1. 任何与NaN一起的运算结果都为NaN
2. 如果`x < -1 || x > 1`，则`math.Acos(x)`、`math.Asin(x)`、`math.Atanh(x)`均返回NaN
3. 如果`x < 1`，则`math.Acosh(x)`返回NaN
4. 如果`x < 0`，则`math.Sqrt(x)`返回NaN

> 应该还有其他返回NaN的情况，老许就不一一总结了。

### NaN的比较

根据静态检查的提示“`no value is equal to NaN, not even NaN itself`”，没有值等于`NaN`甚至于它自己都不是它自己。为了做更进一步的验证，我们看下面代码和输出。

```go
nan := math.NaN()
positiveInf := math.Inf(1)
negativeInf := math.Inf(-1)
fmt.Println(nan == nan)

fmt.Println(nan > 1024) // 输出：false
fmt.Println(nan < 1024) // 输出：false
fmt.Println(nan == 1024) // 输出：false
fmt.Println(nan > positiveInf) // 输出：false
fmt.Println(nan < negativeInf) // 输出：false
fmt.Println(nan == positiveInf) // 输出：false
fmt.Println(nan == negativeInf) // 输出：false
```

确实，如提示所说，`NaN`不等于它自己，且它和任何值比较时都为`false`。由于`NaN`的特殊性，所以在实际开发中我们一定要注意边界值的处理。

## 写在最后

本文主要讲解了除以常量`0`、整形`0`和浮点数`0`的各种情况，以及对`±Inf`和`NaN`的可比性做了分析。下面是一张各种值是否可比的对照表。

| 是否可比   | +Inf | -Inf | NaN | Number |
|:------ |:---- |:---- |:--- |:------ |
| +Inf   | Y    | Y    | N   | Y      |
| -Inf   | Y    | Y    | N   | Y      |
| Nan    | N    | N    | N   | N      |
| Number | Y    | Y    | N   | Y      |

> 这里说的不可比主要指NaN和任何值比较都返回false

最后，衷心希望本文能够对各位读者有一定的帮助。

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)