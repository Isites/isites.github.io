---
title: "白话Go内存模型&Happen-Before"
date: 2021-03-04T18:53:38+08:00
draft: true
toc: true
images:
tags:
  - Go
---

Go内存模型明确指出，一个goroutine如何才能观察到其他goroutine对同一变量的写操作。

当多个goroutine并发同时存取同一个数据时必须把并发的存取操作序列化。在Go中保证读写的序列化可以通过channel通信或者其他同步原语（例如sync包中的互斥锁、读写锁和sync/atomic中的原子操作）。

# Happens Before

在单goroutine中，读取和写入的行为一定是和程序指定的执行顺序表现一致。换言之，编译器和处理器在不改变语言规范所定义的行为前提下才可以对单个goroutine中的指令进行重排序。 

```go
a := 1
b := 2
```
由于指令重排序，`b := 2`可能先于`a := 1`执行。单goroutine中，该执行顺序的调整并不会影响最终结果。但多个goroutine场景下可能就会出现问题。

```go
var a, b int
// goroutine A
go func() {
    a := 5
    b := 1
}()
// goroutine B
go func() {
    for b == 1 {}
    fmt.Println(a)
}()
```
执行上述代码时，预期goroutine B能够正常输出5，但因为指令重排序，`b := 1`可能先于`a := 5`执行，最终goroutine B可能输出0。

> **注**：上述例子是个不正确的示例，仅作说明用。

为了明确读写的操作的要求，Go中引入了`happens before`，它表示执行内存操作的一种偏序关系。

## happens-before的作用

多个goroutine访问共享变量时，它们必须建立同步事件来确保happens-before条件，以此确保读能够观察预期的写。

## 什么是Happens Before

如果事件e1发生在事件e2之前，那么我们说e2发生在e1之后。 同样，如果e1不在e2之前发生也没有在e2之后发生，那么我们说e1和e2同时发生。

在单个goroutine中，happens-before的顺序就是程序执行的顺序。那happens-before到底是什么顺序呢？我们看看下面的条件。

如果对于一个变量v的读操作r和写操作w满足下述两个条件，r才**允许**观察到w：
1. r没有发生在w之前。
2. 没有其他写操作发生在w之后和r之前。

为了保证变量v的一个读操作r能够观察到一个特定的写操作w，需要确保w是唯一允许被r观察的写操作。那么，如果 r、w 都满足以下条件，r就能**确保**观察到w：
1. w发生在r之前。
2. 其他写操作发生在w之前后者r之后。

单goroutine中不存在并发，这两个条件是等价的。老许在此基础上扩展一下，对于单核心的运行环境这两组条件同样等价。并发情况下，后一组条件比第一组更加严格。

假如你很疑惑，那就对了！老许最开始也很疑惑，这两组条件就是一样的呀。为此老许特地和原文进行了反复对比确保上述的理解是没有问题的。

![](https://note.youdao.com/yws/api/personal/file/WEBebd7cd55c1ff407b05900807355c9010?method=download&shareKey=91b03f6fdf992ed04c06d873219e3725)

我们换个思路，进行反向推理。如果这两组条件一样，那原文没必要写两次，果然此事并不简单。

![](https://note.youdao.com/yws/api/personal/file/WEB9ef1aa573f52434032ce40c6d525509f?method=download&shareKey=464df8124d6c3a538a5f20189d68890c)

在继续分析之前，要先感谢一下我的语文老师，没有你我就无法发现它们的不同。

`r没有发生在w之前`，则r可能的情况是r发生在w之后或者和w同时发生，如下图（实心表示可同时）。

![](https://note.youdao.com/yws/api/personal/file/WEB9d6ef4da5ed351b7be9714404cea7a16?method=download&shareKey=535d89b4786491f6b3ae27f7527b34bf)

`没有其他写操作发生在w之后和r之前`，则其他写w'可能发生在w之前或者和w同时发生，也可能发生在r之后或者和r同时发生，如下图（实心表示可同时）。

![](https://note.youdao.com/yws/api/personal/file/WEBb31fc5b4f9b84711a39f34270bd4eca1?method=download&shareKey=7cb5b00eca87f4552676665227d2ccd5)

第二组条件就很明确了，w发生在r之前且其他写操作只能发生在w之前或者r之后，如下图（空心表示不可同时）。

![](https://note.youdao.com/yws/api/personal/file/WEBcd7396985d35dba916d914f9139d2ca0?method=download&shareKey=bcaa56ab18dd267da16c10431ddad674)

到这儿应该明白为什么第二组条件比第一组条件更加严格了吧。在第一组的条件下是允许观察到w，第二组是保证能观察到w。

# Go中的同步

下面是Go中约定好的一些同步事件，它们能确保程序遵循happens-before原则，从而使并发的goroutine相对有序。

## Go的初始化

程序初始化运行在单个goroutine中，但是该goroutine可以创建其他并发运行的goroutine。

如果包p导入了包q，则q包init函数执行结束先于p包init函数的执行。main函数的执行发生在所有init函数执行完成之后。

## goroutine的创建结束

goroutine的创建先于goroutine的执行。老许觉得这基本就是废话，但事情总是没有那么简单，其隐含之意大概是goroutine的创建是阻塞的。

 ```go
func sleep() bool {
	time.Sleep(time.Second)
	return true
}
 
go fmt.Println(sleep())
 ```

上述代码会阻塞主goroutine一秒，然后才创建子goroutine。

goroutine的退出是无法预测的。如果用一个goroutine观察另一个goroutine，请使用锁或者Channel来保证相对有序。

## Channel的发送和接收

Channel通信是goroutine之间同步的主要方式。

* Channel的发送动作先于相应的接受动作完成之前。

* 无缓冲Channel的接受先于该Channel上的发送完成之前。

这两点总结起来分别是`开始发送`、`开始接受`、`发送完成`和`接受完成`四个动作，其时序关系如下。

```shell
开始发送 > 接受完成
开始接受 > 发送完成
```
> 注意：开始发送和开始接受并无明确的先后关系

* Channel的关闭发生在由于通道关闭而返回零值接受之前。

* 容量为C的Channel第k个接受先于该Channel上的第k+C个发送完成之前。

这里使用极限法应该更加易于理解，如果C为0，k为1则其含义和无缓冲Channel的一致。

## Lock

对于任何sync.Mutex或sync.RWMutex变量l以及n < m，第n次l.Unlock()的调用先于第m次l.Lock()的调用返回。

假设n为1，m为2，则第二次调用l.Lock()返回前一定要先调用l.UnLock()。

对于sync.RWMutex的变量l存在这样一个n，使得l.RLock()的调用返回在第n次l.Unlock()之后发生，而与之匹配的l.RUnlock()发生在第n + 1次l.Lock()之前。

不得不说，上面这句话简直不是人能理解的。老许将其翻译成人话：

有写锁时：l.RLock()的调用返回发生在l.Unlock()之后。

有读锁时：l.RUnlock()的调用发生在l.Lock()之前。

> 注意：调用l.RUnlock()前不调用l.RLock()和调用l.Unlock()前不调用l.Lock()会引起panic。

## Once

once.Do(f)中f的返回先于任意其他once.Do的返回。

# 不正确的同步

**错误示范一**

```go
var a, b int

func f() {
	a = 1
	b = 2
}

func g() {
	print(b)
	print(a)
}

func main() {
	go f()
	g()
}
```
这个例子看起来挺简单，但是老许相信大部分人应该会忽略指令重排序引起的异常输出。假如goroutine f指令重排序后，`b=2`先于`a=1`发生，此时主goroutine观察到b发生变化而未观察到a变化，因此有可能输出`20`。

> 老许在本地实验了多次结果都是输出`00`，`20`这个输出估计只活在理论之中了。

**错误示范二**

```go
var a string
var done bool

func setup() {
	a = "hello, world"
	done = true
}

func doprint() {
	if !done {
		once.Do(setup)
	}
	print(a)
}

func twoprint() {
	go doprint()
	go doprint()
}
```

这种双重检测本意是为了避免同步的开销，但是依旧有可能打印出空字符串而不是“hello, world”。说实话老许自己都不敢保证以前没有写过这样的代码。现在唯一能想到的场景就是其中一个goroutine doprint执行到`done = true`（指令重排序导致`done=true`先于`a="hello, world"`执行）时，另一个goroutine doprint刚开始执行并观察到done的值为true从而打印空字符串。

最后，衷心希望本文能够对各位读者有一定的帮助。当然，发现错误也还请及时联系老许改正。

**参考**

https://golang.org/ref/mem


【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)