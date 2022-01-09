---
title: "探讨系统中💰钱的精度问题"
date: 2021-12-20T12:20:38+08:00
draft: true
toc: true
images:
tags:
  - Go
---

> `钱,乃亘古之玄物,有则气粗神壮,缺则心卑力浅`

在一个系统中，特别是一个和钱相关的系统，钱乃重中之重，计算时的精度将是本篇讨论的主题。

## 精度为何如此重要

“积羽沉舟”用在此处最为合适。假如某电商平台每年订单成交数量为10亿，每笔订单少结算1分钱，则累计损失`1000万`！有一说一，这损失的钱就是王某人的十分之一个小目标。如果因为精度问题在给客户结算时，少算会损失客户，多算会损失钱。由此可见，精确的计算钱十分重要！

## 为什么会有精度的问题

经典案例，我们来看一下`0.1 + 0.2`在计算机中是否等于`0.3`。

![](https://note.youdao.com/yws/api/personal/file/WEBf804d312461f4ec67ccd01132997ffff?method=download&shareKey=d0bf734abc1fe9de099227c381b3bb17)


上述case学过计算机的应该都知道，计算机是二进制的，用二进制表示浮点数时(IEEE754标准)，只有少量的数可以用这种方法精确的表示出来。下面以0.3为例看一下十进制转二进制小数的过程。

![](https://note.youdao.com/yws/api/personal/file/WEB5b5f3c3225eb1ed793afcf58b832bb90?method=download&shareKey=8a5ae11fcdb830ec79006aea6b09a560)

计算机的位数有限制，因此计算机用浮点数计算时肯定无法得到精确的结果。这种硬限制无法突破，所以需要引入精度以保证对钱的计算在允许的误差范围内尽可能准确。


> 关于浮点数在计算机中的实际表示本文不做进一步讨论，可以参考下述连接学习：
>
> 单精度浮点数表示：
>
> https://en.wikipedia.org/wiki/Single-precision_floating-point_format
>
> 双精度浮点数表示：
>
> https://en.wikipedia.org/wiki/Double-precision_floating-point_format
>
> 浮点数转换器：
>
> https://www.h-schmidt.net/FloatConverter/IEEE754.html

## 用浮点数计算

还是以上述`0.1 + 0.2`为例，`0.00000000000000004`的误差完全可以忽略，我们尝试小数部分保留5位精度，看下面结果。

![](https://note.youdao.com/yws/api/personal/file/WEBa904cba0f98c32314621cf074596c667?method=download&shareKey=4a3cfa75c5e38ec58ec3ebc408d6c583)

此时的结果符合预期。这也是为什么很多时候判断两个浮点数是否相等往往采用`a - b <= 0.00001`的形式，说白了这就是小数部分保留5位精度的另一种表现形式。

## 用整型计算

前面提到只有少量的浮点数可以用IEEE754标准表示，而整型可精确表示所有有效范围内的数。因此很容易想到，使用整型表示浮点数。

例如，事先定好小数保留8位精度，则`0.1`和`0.2`分别表示成整数为`10000000`和`20000000`,  浮点数的运算也就转换为整型的运算。还是以`0.1 + 0.2`为例。

```go
// 表示小数位保留8位精度
const prec = 100000000

func float2Int(f float64) int64 {
	return int64(f * prec)
}

func int2float(i int64) float64 {
	return float64(i) / prec
}
func main() {
	var a, b float64 = 0.1, 0.2
	f := float2Int(a) + float2Int(b)
	fmt.Println(a+b, f, int2float(f))
	return
}
```

上述代码输出结果如下：

![](https://note.youdao.com/yws/api/personal/file/WEB90f4a3faef6fab8ce5230655a4e4b695?method=download&shareKey=7516cb7b6cbd33c1953bcff518cb93d8)

上述输出结果完全符合预期，所以用整型来表示浮点数看起来是一个可行的方案。但，我们不能局限于个例，还需要更多的测试。

```go
fmt.Println(float2Int(2.3))
```
上述代码输出结果如下：

![](https://note.youdao.com/yws/api/personal/file/WEBefdbec902ab6904b50790c6dd7c930f4?method=download&shareKey=453064325c56910cf93cb28c166de7cd)

这个结果是如此的出乎意料，却又是情理之中。

![](https://note.youdao.com/yws/api/personal/file/WEBe786aa264db530711fa0ab6330c2d52e?method=download&shareKey=80360e18093eac4da4fa7da3629e7aaf)

上图表示`2.3`在计算机中实际的存储值，因此使用`float2Int`函数进行转换时的结果是`229999999`而不是`230000000`。

这个结果很明显不符合预期，在确定的精度范围内仍有精度损失，如果把这个代码发到线上，很大概率第二天就会光速离职。要解决这个问题也很简单，只需引入`github.com/shopspring/decimal`即可，看下面修正后的代码。

```go
// 表示小数位保留8位精度
const prec = 100000000

var decimalPrec = decimal.NewFromFloat(prec)

func float2Int(f float64) int64 {
	return decimal.NewFromFloat(f).Mul(decimalPrec).IntPart()
}

func main() {
	fmt.Println(float2Int(2.3)) // 输出：230000000
}
```
此时结果符合预期，系统内部的浮点运算(加法、减法、乘法)均可转换为整型运算，而运算结果只需要一次浮点转换即可。

到这里，用整型计算基本能满足大部分场景，但仍有两个问题尚需注意。

1、整型表示浮点数的范围是否满足系统需求。

2、整型表示浮点数时除法依旧需要转换为浮点数运算。

**整型表示浮点数的范围**

以`int64`为例，数值范围为`-9223372036854775808～9223372036854775807`，如果我们对小数部分精度保留8位，则剩余表示整数部分依旧有11位，即只表示钱的话仍旧可以存储上`百亿`的金额，这个数值对很多系统和中小型公司而言已经绰绰有余，但是使用此方式存储金额时范围依旧是需要慎重考虑的问题。

**整型表示浮点数的除法**

在Go中没有隐式的整型转浮点的说法，即整型和整型相除得到的结果依旧是整型。我们以整型表示浮点数时，就尤其需要注意整型的除法运算会丢失所有的小数部分，所以一定要先转换为浮点数再进行相除。


## 浮点和整型的最大精度

 `int64`的范围为`-9223372036854775808～9223372036854775807`，则用整型表示浮点型时，整数部分和小数部分的有效十进制位最多为`19`位。

`uint64`的范围为`0~18446744073709551615`，则用整型表示浮点型时，整数部分和小数部分的有效十进制位最多为`20`位，因为系统中表示金额时一般不会存储负数，所以和`int64`相比，更加推荐使用`uint64`。

`float64`根据IEEE754标准，并参考维基百科知其整数部分和小数部分的有效十进制位为`15-17`位。

![](https://note.youdao.com/yws/api/personal/file/WEBb978e1253b122cb3d36f2db17ede350d?method=download&shareKey=c34eac96cb76f0e7f4b1acc3da4aabac)

我们看下面的例子。

```go
var (
	a float64 = 123456789012345.678
	b float64 = 1.23456789012345678
)

fmt.Println(a, b, decimal.NewFromFloat(a), a == 123456789012345.67)
return
```

上述代码输出结果如下：

![](https://note.youdao.com/yws/api/personal/file/WEB1c85da3c9f69f02b709dc1f3b3efda68?method=download&shareKey=e4d4c9207af46a31a3dfab77119ce4ae)

根据输出结果知，`float64`无法表示有效位数超过17位的十进制数。从有效十进制位来讲，老许更加推荐使用整型表示浮点数。


## 计算中尽量保留更多的精度

前面提到了精度的重要性，以及整型和浮点型可表示的最大精度，下面我们以一个实际例子来探讨计算过程中是否要保留指定的精度。

```go
var (
	// 广告平台总共收入7.11美元
	fee float64 = 7.1100
	// 以下是不同渠道带来的点击数
	clkDetails = []int64{220, 127, 172, 1, 17, 1039, 1596, 200, 236, 151, 91, 87, 378, 289, 2, 14, 4, 439, 1, 2373, 90}
	totalClk   int64
)
// 计算所有渠道带来的总点击数
for _, c := range clkDetails {
	totalClk += c
}
var (
	floatTotal float64
	// 以浮点数计算每次点击的收益
	floatCPC float64 = fee / float64(totalClk)
	intTotal int64
	// 以8位精度的整形计算每次点击的收益(每次点击收益转为整形)
	intCPC        int64 = float2Int(fee / float64(totalClk))
	intFloatTotal float64
	// 以8位进度的整形计算每次点击的收益(每次点击收益保留为浮点型)
	intFloatCPC  float64 = float64(float2Int(fee)) / float64(totalClk)
	decimalTotal         = decimal.Zero
	// 以decimal计算每次点击收益
	decimalCPC = decimal.NewFromFloat(fee).Div(decimal.NewFromInt(totalClk))
)
// 计算各渠道点击收益，并累加
for _, c := range clkDetails {
	floatTotal += floatCPC * float64(c)
	intTotal += intCPC * c
	intFloatTotal += intFloatCPC * float64(c)
	decimalTotal = decimalTotal.Add(decimalCPC.Mul(decimal.NewFromInt(c)))
}
// 累加结果对比
fmt.Println(floatTotal) // 7.11
fmt.Println(intTotal) // 710992893
fmt.Println(decimal.NewFromFloat(intFloatTotal).IntPart()) // 711000000
fmt.Println(decimalTotal.InexactFloat64()) // 7.1100000000002375
```
对比上面的计算结果，只有第二种精度最低，而造成该精度丢失的主要原因是`float2Int(fee / float64(totalClk))`将中间计算结果的精度也只保留了`8`位，因此在结果上面产生了误差。其他计算方式在中间计算过程中尽可能的保留了精度因此结果符合预期。

## 除法和减法的结合

根据前面的描述，在计算除法的过程中要使用浮点数且尽可能保留更多的精度。这依旧不能解决所有问题，我们看下面的例子。

```go
// 1元钱分给3个人，每个人分多少？
var m float64 = float64(1) / 3
fmt.Println(m, m+m+m)
```

上述代码输出结果如下：

![](https://note.youdao.com/yws/api/personal/file/WEB4f1cb1ac8d81826e284b9a111085e239?method=download&shareKey=c521e6d17a3a73ff778842e10fcd1736)

由计算结果知，每人分得`0.3333333333333333`元，而将每人分得的钱再次汇总时又变成了`1`元，那么
这`0.0000000000000001`元是从石头里面蹦出来的嘛！有些时候我真的搞不懂这些计算机。

这个结果很明显不符合人类的直觉，为了更加符合直觉我们结合减法来完成本次计算。

```go
// 1元钱分给3个人，每个人分多少？
var m float64 = float64(1) / 3
fmt.Println(m, m+m+m)
// 最后一人分得的钱使用减法
m3 := 1 - m - m
fmt.Println(m3, m+m+m3)
```

上述代码输出结果如下：

![](https://note.youdao.com/yws/api/personal/file/WEBe8a9929dbaded2c1aa2f8e0e65eacce2?method=download&shareKey=8fbef3b6e5cb8520149b4ad62c3f753c)

通过减法我们终于找回了那丢失的`0.0000000000000001`元。当然上面仅是老许举的一个例子，在实际的计算过程中可能需要通过`decimal`库进行减法以保证钱不凭空消失也不凭空增加。


以上均为老许的浅薄之见，有任何疑虑和错误请及时指出，衷心希望本文能够对各位读者有一定的帮助。

> 注：
>
> 写本文时， 笔者所用go版本为: go1.16.6
>
> 文章中所用部分例子：https://github.com/Isites/go-coder/blob/master/money/main.go


【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)