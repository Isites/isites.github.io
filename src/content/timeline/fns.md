---
title: "惊！Go里面居然有这样精妙的小函数！"
date: 2021-08-03T21:00:00+08:00
draft: true
toc: true
images:
tags:
  - Go
---


各位哥麻烦腾个道，前面是大型装逼现场。

![](https://note.youdao.com/yws/api/personal/file/WEBe4065167c25d3997e1de76682278cdb4?method=download&shareKey=cfbd95aa6ed1cb7f611be67d06c381c3)

首先老许要感谢他人的认同，这是我乐此不彼的动力，同时我也需要反思。这位小姐姐还是比较委婉， 但用我们四川话来说，[前一篇文章](https://mp.weixin.qq.com/s/2MGYuqT_Xzy2_MwteQruQw)的标题是真的`cuo`。

老许反复思考后决定哗众取宠一波，感叹号双连取名曰“**惊！Go里面居然有这样精妙的小函数！**”。下面就让我们来看看和标题没那么符合的一些小函数。


**返回a/b向上舍入最接近的整数**

```go
func divRoundUp(n, a uintptr) uintptr {
	return (n + a - 1) / a
}
```

这个方法用过的人应该不少，最典型的就是分页计算。


**判断x是否为2的n次幂**

```go
func isPowerOfTwo(x uintptr) bool {
	return x&(x-1) == 0
}
```

这个也挺容易理解的，唯一需要注意的是x需要大于0，因为该等式0也是成立的。

**向上/下将x舍入为a的倍数，且a必须是2的n次幂**

```go
// 向上将x舍入为a的倍数，例如：x=6，a=4则返回值为8
func alignUp(x, a uintptr) uintptr {
	return (x + a - 1) &^ (a - 1)
}

// 向上将x舍入为a的倍数，例如：x=6，a=4则返回值为4
func alignDown(x, a uintptr) uintptr {
	return x &^ (a - 1)
}

```

在这里老许再次明确一个概念，`2的n次幂即为1左移n位`。然后上述代码中`^`为单目运算法按位取反，则`^ (a - 1)`的运算结果是除了最低n位为0其余位全为1。剩余的部分则是一个简单的加减运算以及按位与。

上述代码分开来看每一部分都认识，合在一起就一脸懵逼了。幸运的是，经过老许的不懈努力终于找到了一种能够理解的方式。

以`x=10，a=4`为例。`a`为2的2次幂即1左移2位。`x`可看作两部分之和，第一部分x1为`0b1000`,第二部分x2为`0b0011`。`x`的拆分方式是1左移`n`位可得到`a`来决定的，即x的最低n位为x2，x1则为x-x2。因此x1相当于0b10左移2位得到，即x1已经是a的整数倍，此时x2只要大于0则x2+a-1一定会向前进1，`x1+1`或`x1`不就是x向上舍入的a的整数倍嘛，最后和`^ (a - 1)`进行与运算将最低2位清零得到最终的返回结果。

有一说一，我肯定是写不出这样的逻辑，这也令我不得不感叹大佬们对计算机的理解简直出神入化。这样的函数牛逼归牛逼，但是在实际开发中还是尽量少用。一是有使用场景的限制（a必须为2的n次幂），二是不易理解，当然炫技和装逼除外（性能要求极高也除外）。


**布尔转整形**

```go
// bool2int returns 0 if x is false or 1 if x is true.
func bool2int(x bool) int {
	return int(uint8(*(*uint8)(unsafe.Pointer(&x))))
}

```

如果让我来写这个函数，一个稀松平常的`switch`就完事儿，而现在我又多了一种装逼的套路。老许在这里特别友情提示，字节切片和字符串也可使用上述方式进行相互转换。

**计算不同类型最低位0的位数**

```go
var ntz8tab = [256]uint8{
	0x08, ..., 0x00,
}
// Ctz8 returns the number of trailing zero bits in x; the result is 8 for x == 0.
func Ctz8(x uint8) int {
	return int(ntz8tab[x])
}

const deBruijn32ctz = 0x04653adf

var deBruijnIdx32ctz = [32]byte{
	0, 1, 2, 6, 3, 11, 7, 16,
	4, 14, 12, 21, 8, 23, 17, 26,
	31, 5, 10, 15, 13, 20, 22, 25,
	30, 9, 19, 24, 29, 18, 28, 27,
}

// Ctz32 counts trailing (low-order) zeroes,
// and if all are zero, then 32.
func Ctz32(x uint32) int {
	x &= -x                       // isolate low-order bit
	y := x * deBruijn32ctz >> 27  // extract part of deBruijn sequence
	i := int(deBruijnIdx32ctz[y]) // convert to bit index
	z := int((x - 1) >> 26 & 32)  // adjustment if zero
	return i + z
}

const deBruijn64ctz = 0x0218a392cd3d5dbf

var deBruijnIdx64ctz = [64]byte{
	0, 1, 2, 7, 3, 13, 8, 19,
	4, 25, 14, 28, 9, 34, 20, 40,
	5, 17, 26, 38, 15, 46, 29, 48,
	10, 31, 35, 54, 21, 50, 41, 57,
	63, 6, 12, 18, 24, 27, 33, 39,
	16, 37, 45, 47, 30, 53, 49, 56,
	62, 11, 23, 32, 36, 44, 52, 55,
	61, 22, 43, 51, 60, 42, 59, 58,
}

// Ctz64 counts trailing (low-order) zeroes,
// and if all are zero, then 64.
func Ctz64(x uint64) int {
	x &= -x                       // isolate low-order bit
	y := x * deBruijn64ctz >> 58  // extract part of deBruijn sequence
	i := int(deBruijnIdx64ctz[y]) // convert to bit index
	z := int((x - 1) >> 57 & 64)  // adjustment if zero
	return i + z
}
```
`Ctz8`、`Ctz32`和`Ctz64`分别计算无符号8、32、64位数最低位为0的个数，即某个数左移的位数。

函数的作用通过翻译倒是能理解，我也能深刻的明白这是典型的空间换时间，然而要问一句为什么我是万万答不上来的。不过老许已经替你们找好了答案，答案就藏在这篇[Using de Bruijn Sequences to Index a 1 in a Computer Word](http://supertech.csail.mit.edu/papers/debruijn.pdf)论文中。欢迎巨佬们去挑战一下，而我只想坐享其成，那么在巨佬们分析完这篇论文之前就让这些函数安家在我的收藏栏里方便以后炫技。

这里特别说明，术业有专攻，我们不一定要所有东西都会，但要尽可能知道有这么一个东西存在。这即是老许为自己找的一个不去研究此论文的接口，也是写下此篇文章的意义之一（万一有人提到了`Bruijn Sequences`关键词，我们也不至于显得过分无知）。


**math/bits包中的部分函数**

如果有人知道这个包，那请原谅我的无知直接跳过本部分即可。老许发现这个包是源于`ntz8tab`变量所在文件`runtime/internal/sys/intrinsics_common.go`中的一句注释。

```
// Copied from math/bits to avoid dependence.
```

作为一个资深的CV工程师， 看到这句的第一反应就是我终于可以挺直腰杆了。适当Copy代码不丢人！

`math/bits`这个包函数较多，老许挑几个介绍即可，其余的还请各位读者自行挖掘。

`LeadingZeros(x uint) int`: 返回x所有高位为0的个数。

`TrailingZeros(x uint) int`: 返回x最低位为0的个数。

`OnesCount(x uint) int`：返回x中bit位为1的个数。

`Reverse(x uint) uint`: 将x按bit位倒序后再返回。

`Len(x uint) int`: 返回表示x的有效bit位个数（高位中的0不计数）。

`ReverseBytes(x uint) uint`: 将x按照每8位一组倒序后返回。


**将x逃逸至堆**

```go
// Dummy annotation marking that the value x escapes,
// for use in cases where the reflect code is so clever that
// the compiler cannot follow.
func escapes(x interface{}) {
	if dummy.b {
		dummy.x = x
	}
}

var dummy struct {
	b bool
	x interface{}
}
```

老许是在`reflect.ValueOf`函数中发现此函数的调用，当时就觉着挺有意思。如今再次回顾也依旧佩服不已。读书是和作者的对话，阅读源码是和开发者的对话，看到此函数就仿佛看到Go语言开发者们和编译器斗智斗勇的场景。

**让出当前Processor**

```go

// Gosched yields the processor, allowing other goroutines to run. It does not
// suspend the current goroutine, so execution resumes automatically.
func Gosched() {
	checkTimeouts()
	mcall(gosched_m)
}

```

让出当前的Processor，允许其他goroutine执行。在实际的开发当中老许还未遇到需要使用此函数的场景，但多了解总是有备无患。


最后，衷心希望本文能够对各位读者有一定的帮助。

> **注**：
> 1. 写本文时， 笔者所用go版本为: go1.16.6

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)