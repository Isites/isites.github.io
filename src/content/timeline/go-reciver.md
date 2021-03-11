---
title: "为什么go中的receiver name不推荐使用this或者self"
date: 2020-08-29T12:20:38+08:00
draft: true
toc: true
images:
tags:
  - Go
---


## 前言
在日常的开发中我们除了定义函数以外， 我们还会定义一些方法。这本来没有什么， 但是一些从PHP或者其他面向对象语言转GO的同学往往会把receiver name命名为`this`, `self`, `me`等。

笔者在实际项目开发中也遇到类似的同学， 屡次提醒却没有效果，于是决心写下这篇文章以便好好说服这些同学。

## CR标准做法

首先我们来看一下GO推荐的标准命名`Receiver Names`，以下内容摘抄自https://github.com/golang/go/wiki/CodeReviewComments#receiver-names：

```
The name of a method's receiver should be a reflection of its identity;
often a one or two letter abbreviation of its type suffices (such as "c" or "cl" for "Client"). 
Don't use generic names such as "me", "this" or "self", identifiers typical of object-oriented languages that gives the method a special meaning. 
In Go, the receiver of a method is just another parameter and therefore, should be named accordingly. 
...
```
简单翻译总结有如下2点：
1. 方法接受者名称应反映其身份， 并且不要使用`me`, `this`, `self`这些面向对象语言的典型标志符。
2. 在go中方法接受者其实就是方法的另一个参数。

## Receiver是方法的第一个参数！

上面的第二点， 可能不是很好理解，所以我们直接看下面的demo：

```go
// T ...
type T int

// Println ...
func (t T) Println() {
	fmt.Println("value: %v", t)
}

func main() {
	t := T(1)
	t.Println()
	T.Println(t) // receiver作为函数的第一个参数，这个时候发生值拷贝，所以方法内部的t变量只是真实t变量的一个拷贝，这和this的含义是不相符的
}
// output:
value: 1
value: 1
```
通过上面的demo， 我们知道接受者可以直接作为第一个参数传递给方法的。而`t.Println()`应该就是Go中的一种语法糖了。

到这里可能有同学又要问了， 既然Go提供了这种语糖，那我们这样命名有什么问题呢？笔者先不着急解释， 我们继续看下面的demo：

```go
// Test ...
type Test struct {
	A int
}

// SetA ...
func (t Test) SetA(a int) {
	t.A = a
}

// SetA1 ...
func (t *Test) SetA1(a int) {
	t.A = a
}

func main() {
	t := Test{
		A: 3,
	}
	fmt.Println("demo1:")
	fmt.Println(t.A)
	t.SetA(5)
	fmt.Println(t.A)
	t1 := Test{
		A: 4,
	}
	fmt.Println("demo2:")
	fmt.Println(t1.A)
	(&t1).SetA1(6)
	fmt.Println(t1.A)
}
// output:
demo1:
3
3
demo2:
4
6
```
看上面的demo我们知道， 当receiver不是指针时调用`SetA`其值根本没有改变。

因为Go中都是值传递，所以你如果对SetA的receiver的名称命名为`this`, `self`等，它就已经失去了本身的意义——“调用一个对象的方法就是向该对象传递一条消息”。而且对象本身的属性也并不一定会发生改变。

**综上**: 请各位读者在对receiver命名时不要再用`this`, `self`等具有特殊含义的名称啦。


## Receiver是可以为nil的！！！

最近在研读`h2_bundle.go`的时候，发现了一段特殊的代码，顿时惊出一身冷汗，姑在本文补充一下，以防止自己和各位读者踩坑。

源代码截图如下：
![](https://note.youdao.com/yws/api/personal/file/WEBf28c8ce7424f4cc7a7620f735a83b9f1?method=download&shareKey=829323e04d513a68e5cfe3c9d61d2a45)

惊出我一身冷汗的正是图中标红的部分，**receiver居然还要判断为nil**！在我的潜意识里一直是这样认为的，receiver默认都是有值的，直接使用就行了。这简直颠覆我的认知，吓得我赶紧写了个demo验证一下：

```go
type A struct {
	v int
}

func (a *A) test() {
	fmt.Println(a == nil)
}

func (a *A) testV() {
	fmt.Println(a.v)
}


func main() {
	var a *A
	a.test()
	a.testV()
}

```

上述输出如下：

![](https://note.youdao.com/yws/api/personal/file/WEBf867c728b16230b0a82d6f9cd9d134ab?method=download&shareKey=bc9e10dedff781d0406ed40e850a8b22)

`a.test()`能够正常输出，只有在处理变量结构体内部变量`v`才报出panic！！！还好本文前面已经介绍了`Receiver是方法的第一个参数`。正因为是第一个参数所以仅仅作为参数传递时即使是`nil`也能够正常调用函数，而在真正使用的地方报出panic。

鉴于receiver如此特殊，所以特意在本文完成之后补充后续内容以时刻提醒自己和各位读者。

> 本部分于20200827日晚补充。

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)