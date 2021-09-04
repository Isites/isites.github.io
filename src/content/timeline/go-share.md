---
title: "公司内一次分享-Go并发编程"
date: 2021-08-17T21:00:00+08:00
draft: true
toc: true
images:
tags:
  - Go
---


提到并发编程，不得不想到Go并发编程中的一句[经典名言](https://blog.golang.org/codelab-share)
```
Do not communicate by sharing memory; instead, share memory by communicating.
```


# 本次分享目标

* 避免Go并发编程一些常见的坑
* 理解为什么Go原生网络编程模型为什么这么爽

# 并发编程踩坑目录

优雅的代码不好定义，每位开发也有自己的风格，但是坑总是相似的。

## channel误用
**Case-1**
```go
func main() {
	wg := sync.WaitGroup{}
	ch := make(chan int, 10)
	for i := 0; i < 10; i++ {
		ch <- i // put task into channel
	}

	close(ch)

	wg.Add(4)
	for j := 0; j < 4; j++ {
		go func() {
			for {
				task := <-ch
				// do sth
				fmt.Println(task)
			}
			wg.Done()
		}()
	}
	wg.Wait()
}
```

<details>
<summary>什么问题？</summary>
ch关闭后是可以一直读到它的默认值，导致goroutine无法退出一直打印默认值0。
</details>


<details>
<summary>怎么避免？</summary>
1、使用task，ok := <-ch读取。第二个参数表示是否从channel读取到数据，因此可以用此来判断是channel数据已读完且已关闭。

2、使用for range读取，当channel关闭时，for循环会自动退出。
</details>

**Case-2**

```go
func main() {
	// ... ...
	handler()
	// ... ...
}

func handler() {
	ch := make(chan string)
	go func() {
		// do sth then put result
		time.Sleep(3 * time.Second)
		ch <- "job result"
	}()

	select {
	case result := <-ch:
		fmt.Println(result)
	case <-time.After(time.Second): //timeout
		return
	}
}

```
<details>
<summary>什么问题？</summary>
导致goroutine泄漏。select命中timeout逻辑，导致channel无消费者，最后发生匿名goroutine泄漏。
</details>

<details>
<summary>怎么避免？</summary>
1、去掉select中的timeout逻辑。

2、使用有buffer的channel。
</details>

**Case-3**
```go
func main() {
	var (
		wg  sync.WaitGroup
		ch  = make(chan int64, 1)
		res int64
	)
	wg.Add(2)
	go func() {
		defer wg.Done()
		ch <- 4
		// do sth
		fmt.Println(atomic.LoadInt64(&res))
	}()
	go func() {
		defer wg.Done()
		// do sth
		atomic.AddInt64(&res, <-ch)
	}()
	wg.Wait()
	close(ch)
}
```
<details>
<summary>输出是什么，结果是否符合预期？</summary>
消费者对消息尚未消费完成，生产者已经返回并调用查询逻辑。

1、不一定符合预期。可能是0也可能是4。

2、即使是无buffer的channel也不一定符合预期
</details>

<details>
<summary>怎么避免？</summary>
1、需要增加其他同步逻辑告知第一个gorutine数据已经处理完成。

2、如果业务场景允许，在两个gorutine结束后再查询。
</details>

**Case-4**

```go
func main() {
	var (
		l  sync.Mutex
		wg sync.WaitGroup
		ch = make(chan int, 1)
	)
	wg.Add(2)
	go func() {
		defer wg.Done()
		l.Lock()
		for i := 0; i < 4; i++ {
			ch <- i
		}
		l.Unlock()
	}()
	go func() {
		defer wg.Done()
		for a := range ch {
			l.Lock()
			fmt.Println(a)
			l.Unlock()
		}

	}()
	wg.Wait()
	close(ch)
}

```
<details>
<summary>什么问题？</summary>
case来源：https://github.com/kubernetes/kubernetes/pull/88286/commits/1208bc34c4e15e80fe357b88c149949c5eb70dc1

生产者先获取锁再生产，消费者先消费再获取锁。生产者将channel填满，而消费者阻塞在获取锁的逻辑，最终导致死锁。
</details>

<details>
<summary>怎么避免？</summary>
这个问题容易出现在代码比较复杂的情况中。channel是并发安全的，不需要加锁。而且我们平时在使用锁的时候，锁的粒度要尽可能的小。
</details>

### channel底层实现

```go
type hchan struct {
	qcount   uint           // 当前队列中剩余元素个数，即len
	dataqsiz uint           // 环形队列长度，即可以存放的元素个数，cap
	buf      unsafe.Pointer // 环形队列指针：队列缓存，头指针，环形数组实现
	elemsize uint16         // 每个元素的大小
	closed   uint32         // 关闭标志位
	elemtype *_type         // 元素类型
	sendx    uint           // 队列下标，指示元素写入时存放到队列中的位置
	recvx    uint           // 队列下标，指示元素从队列的该位置读出
	recvq    waitq          // 等待读消息的goroutine队列
	sendq    waitq          // 等待写消息的goroutine队列

	// lock protects all fields in hchan, as well as several
	// fields in sudogs blocked on this channel.
	//
	// Do not change another G's status while holding this lock
	// (in particular, do not ready a G), as this can deadlock
	// with stack shrinking.
	lock mutex              // 该锁保护hchan所有字段
}
```

#### 发送消息的流程
源码见`runtime/chan.go`中的`chansend`函数。

![](https://note.youdao.com/yws/api/personal/file/WEB8ecf38653e087013e72abaf66b69e432?method=download&shareKey=dfc2583d4f9c4fff497082679b768120)

~~#### 接受消息的流程
源码见`runtime/chan.go`中的`chanrecv`函数。~~

### channel使用场景总结
* 同步信号（shutdown/close/finish）
* 消息传递（queue/stream）
* 互斥（mutex）

### channel不同操作和不通状态总结

|操作|nil的channel|已关闭channel|正常channel|
|:------|:------|:------|:------|
|close|`panic`|`panic`|成功|
|block read|`死锁`|零值|阻塞或成功|
|block write|`死锁`|`panic`|阻塞或成功|
|non-block read|正常|零值|等待下次写入或成功|
|non-block write|正常|`panic`|等待下次写入或成功|


## mutext/rwmutext误用


**Case-5**
```go
func do(i int) error {
	if i < 0 {
		return errors.New("")
	}
	return nil
}
func main() {
	var l sync.Mutex
	l.Lock()
	if do(4) != nil {
		fmt.Println("have err")
		return
	}
	l.Unlock()
}

```
<details>
<summary>什么问题？</summary>
漏掉了Unlock，函数下次进入时会无法获取到锁。
</details>

<details>
<summary>怎么避免？</summary>
1、在return前增加Unlock的调用

2. defer unlock，但是需要注意使用此方式会增加锁粒度
</details>


**Case-6**
```go
func main() {
	var (
		wg sync.WaitGroup
		mu sync.RWMutex
	)

	wg.Add(5)
	go func() {
		defer wg.Done()
		mu.RLock()
		time.Sleep(5 * time.Second)
		mu.RUnlock()
	}()
	time.Sleep(time.Second)
	// 加写锁，此时reader0还未释放锁
	go func() {
		defer wg.Done()
		fmt.Println("writer0 Call Lock")
		mu.Lock()
		fmt.Println("writer0 Lock")
		time.Sleep(5 * time.Second)
		fmt.Println("writer0 Call UnLock")
		mu.Unlock()
		fmt.Println("writer0 UnLocked")
	}()
	time.Sleep(time.Second)
	// 加读锁，此时reader0还未释放锁
	for i := 1; i <= 3; i++ {
		go func(idx int) {
			defer wg.Done()
			fmt.Printf("reader%d Call RLock\n", idx)
			mu.RLock()
			fmt.Printf("reader%d RLock\n", idx)
			time.Sleep(3 * time.Second)
			fmt.Printf("reader%d Call RUnLock\n", idx)
			mu.RUnlock()
			fmt.Printf("reader%d RUnLocked\n", idx)
		}(i)
	}
	wg.Wait()
}
```

<details>
<summary>一个writer和3个reader同时尝试获取一个已加读锁的RWMutext，谁先获取到锁？</summary>
写锁会先获取到锁。

被加读锁时，写操作进来会被阻塞。在写操作阻塞期间，如果有读操作试图进来，它们也会被阻塞。当阻塞写操作的最后一个读操作解读锁时，它只会唤醒被阻塞的写操作，之后进来的读操作需要该写操作完成之后被唤醒。
</details>

**Case-7**
```go
var mu sync.RWMutex

func main() {
	go A1()
	time.Sleep(2 * time.Second)

	fmt.Println("w call lock")
	mu.Lock()
	defer mu.Unlock()

}
func A1() {
	fmt.Println("a1 call rlock")
	mu.RLock()
	fmt.Println("a1 rlocked")
	defer mu.RUnlock()
	B2()
}
func B2() {
	time.Sleep(5 * time.Second)
	C3()
}
func C3() {
	fmt.Println("c3 call rlock")
	mu.RLock()
	fmt.Println("c3 rlocked")
	defer mu.RUnlock()
}
```

<details>
<summary>什么问题？</summary>
程序会死锁！！！rlock不可递归调用！！！

A1使用了defer， 使RLock()递归调用，递归调用导致已经等待Lock发生死锁。
</details>


### 一些建议

* Lock和UnLock配套使用
* 运行时离开当前逻辑就释放锁
* 锁的粒度越小越好，加锁后尽快释放锁
* 没有特殊原因尽量不用defer释放锁
* rwmutext的读锁不要嵌套使用

## map/sync.Map

**map**不可并发写！

**sync.Map**可并发读写

**sync.Map特性**

* 通过read和dirty两个字段将读写分离，读取时会先查询read，不存在再查询dirty， 新增时只写入dirty（如果是更新，直接更新对应指针的值，dirty和read中的值都会被更新）
* 读取read并不需要加锁，而读写dirty都需要加锁
* 另外有miss字段来统计read被穿透的次数（被穿透指需要读dirty的情况），当miss次数大于等于`len(dirty)`则将read替换为dirty，然后将dirty置为nil
* 对于在read中的数据删除，并没有真正删除key，而是从key中取出了entry，然后把`entry.p` 设为nil等待gc回收。


**Go1.15陷阱**
```go
func main() {
    var sm sync.Map
    for i := 0; i < 1 << 26; i++ {
        var value [1000]int
        value[0] = i
        sm.Store(value, i)
        if i > 0 {
          sm.Delete(value)
        }
    }
}
```
这段代码只写不读然后删除，在Go1.15中会造成内存泄漏。

因为只写未读，所以数据一直在dirty中，而go1.15因为下面的提交去掉了对只在dirty中的数据删除时的`delete`操作，导致dirty中key和value一直存在从而造成内存泄漏。

https://github.com/golang/go/commit/2e8dbae85ce88d02f651e53338984288057f14cb#diff-4bf757695a75598d57e2b575987c626d4502cc0b2a08c5b0d3e535fa63de0d1e

后在1.16中通过下面的提交修复了此问题

https://github.com/golang/go/commit/94953d3e5928c8a577bad7911aabbf627269ef77

但这个使用姿势肯定是不对的。

在1.16中完整的删除流程如下：
![](https://note.youdao.com/yws/api/personal/file/WEBde06ccde2c76b53dfe44cae788c5f39e?method=download&shareKey=2bb25b590fb012e9c2a1b29365855b9d)

**总结**：
1. 在GO1.15中不要只写不读。
2. 在任何版本中一定要注意key的大小。

### map+rwmutext和sync.map使用场景

到底是使用`map+rwmutext`还是使用`sync.map`， 我汇总了不同的资料。

1、官方文档注释（`sync/map.go`）

```
// The Map type is optimized for two common use cases: (1) when the entry for a given
// key is only ever written once but read many times, as in caches that only grow,
// or (2) when multiple goroutines read, write, and overwrite entries for disjoint
// sets of keys. In these two cases, use of a Map may significantly reduce lock
// contention compared to a Go map paired with a separate Mutex or RWMutex.
```
1)、读特别多，写很少的场景适合sync.Map

2、并发读写的key无冲突时适合sync.Map


2、博客 https://medium.com/@deckarep/the-new-kid-in-town-gos-sync-map-de24a6bf7c2c

![](https://note.youdao.com/yws/api/personal/file/WEB029950a3d70bd54a2b60197b875c069f?method=download&shareKey=26b37691f6c11643347062a45ce4f172)

上图说明超过4核后，sync.Map更具有优势。

3、 其他人benchmark结果

![](https://note.youdao.com/yws/api/personal/file/WEB3842670b32c483a0b15105ef1d4eaad4?method=download&shareKey=1cbb603faddceb491e0d52cb82f6bc5c)

读和删除sync.Map比map+rwmutext和map+mutext性能更好

**结论**：

读比较多的场景`sync.Map`更具有优势，读写相对均衡则`map+rwmutext`更加适合。


## sync.Once误用

**Case-8**
```go
func main() {
	count := 0
	once := sync.Once{}
	go func() {
		defer func() {
			if e := recover(); e != nil {
				fmt.Println("recovered from once")
			}
		}()
		once.Do(func() {
			fmt.Println("once in goroutine")
			count = 1 / count
		})
	}()
	
	time.Sleep(time.Second)
	once.Do(func() {
		fmt.Println("once in main")
		count = 1 / count
	})
	fmt.Println("end")
}
```

<details>
<summary>什么问题？</summary>
goroutine panic后main函数中的once也无法执行了。

这意味着因为某些未考虑到的极端情况导致初始化未完成，那么整个初始化逻辑不可重入。所以我们在使用once的时候一定要注意可能引起panic的情况。
</details>

### once和单例

**懒汉模式**

* 需要的时候才创建，空间效率更优
* 同时需要考虑double check的问题

可添加get方法使用once实现，或者使用mutext自己实现（需要考虑double check）

**饿汉模式**
* 事先创建好，需要时直接返回，代码相对简洁

为避免并发问题，可在init中创建，或者在使用前创建（注意不要并发创建，否则又要加锁）。


## WaitGroup误用

**Case-9**
```go
func main() {
	var wg sync.WaitGroup
	var count int64
	for i := 0; i < 1000; i++ {
		go func() {
			wg.Add(1)
			atomic.AddInt64(&count, 1) // do sth
			wg.Done()
		}()
	}
	wg.Wait()
	fmt.Printf("done! count:%v\n", atomic.LoadInt64(&count))
}
```
<details>
<summary>什么问题？</summary>
count输出结果不一定为1000，而且有可能会引起panic。下面是测试了很多次才出现的panic。

<img src ="https://note.youdao.com/yws/api/personal/file/WEB050e8735521696c0f80e2059229c85f7?method=download&shareKey=738fdab2a74ffa05f1575842f9258f52" />
</details>

### 一些建议

* 统一Add（不要并发Add），分别Done，避免尚未Add就Wait
* 不能将计数器设置为负数，否则会发生panic。例如：Add 负数或Done调用次数大于总数
* WaitGroup可以重用的，但是需要等上一批的goroutine都调用wait完毕后才能继续重用WaitGroup

```
// 还没wait结束就add可能会有这个panic，不过我目前尚未复现
panic("sync: WaitGroup is reused before previous Wait has returned")
```


## sync.Cond误用

**使用场景**：

我需要完成一项任务，但是这项任务需要满足一定条件才可以执行，否则我就等着。
那我可以怎么获取这个条件呢？一种是循环获取，另一种是条件满足的时候通知我就可以了。显然第二种效率高很多。
golang里面通知可以用channel的方式进行通知， 但是channel的方式还是比较适用于一对一，一对多则还是sync.Cond更加方便。

**Case-10**

```go
func main() {
	m := sync.Mutex{}
	c := sync.NewCond(&m)
	go func() {
		time.Sleep(1 * time.Second)
		c.Broadcast()
	}()
	c.L.Lock()
	time.Sleep(2 * time.Second)
	c.Wait()
	c.L.Unlock()
}
```
<details>
<summary>什么问题？</summary>
会死锁，因为groutine在等待之前就已经将通知发出去了，这之后再没有通知可以唤醒处于等待状态的goroutine。
</details>

### 一些建议
* `Wait`调用尽量要在某种条件不满足的情况下才调用，不要使用这种方式将goroutine挂起以达到某种暂停执行的目的。
* `Broadcast`必须要在所有的Wait之后, 或者说一定要有一个`Boradcast`后于最后一次`Wait`调用。

> Broadcast， 用于唤醒所有处于等待状态的gorutine，Signal则是用于唤醒某一个处于等待状态的gorutine

## defer误用
**Case-11**

```go
func main() {
	wg := sync.WaitGroup{}
	wg.Add(1)
	go func() {
		defer wg.Done()
		start := time.Now()
		defer fmt.Printf("logging job cost: %v\n", time.Since(start))
		fmt.Printf("logging at job start: %v\n", start)
		// do sth
		time.Sleep(time.Second)
	}()
	wg.Wait()
	time.Sleep(time.Second)
}
```
<details>
<summary>这段代码是否能达到预期？</summary>
defer对表达式进行提前求值，所以上述例子计算耗时是在调用defer时计算的而不是函数返回后计算。

更适合的方式是defer+闭包。
</details>

**Case-12**

```go
func main() {
	i := 1
	j := add(&i)
	fmt.Println("i :", i)
	fmt.Println("j :", j)
}

func add(n *int) int {
	defer func() {
		*n = *n + 1
	}()
	return *n
}

```
<details>
<summary>请说出打印的i和j的值？</summary>
输出分别为2，1

函数执行流程：

1、defer将匿名函数压栈

2、函数返回时将返回值*n存入函数返回值区域

3、defer调用执行，*n被增加（即i）

4、函数退出，j使用返回值赋值自己

5、打印i、j
</details>

**Case-13**
```go
// Case-13
func main() {
	fmt.Println(fn())
}
func fn() (n int) {
	defer func() {
		n += n
	}()
	n = 1
	return n
}

```
<details>
<summary>打印结果是什么？</summary>
输出为2

函数执行流程：

1、defer将匿名函数压栈的同时将返回值的地址（栈中的地址）传递给defer函数

2、return语句将1存入函数返回值区域

3、defer调用执行，更新返回值区域的值

4、函数退出，主调函数就会获取到defer修改后的返回值

扩展：为什么defer能够修改有名返回值

<img src="https://note.youdao.com/yws/api/personal/file/WEB3325f4d8f7d0b7bfd9e506c83054a01d?method=download&shareKey=56069e8860dc35bc337c75b90d6bf096"/>

</details>


### 一些建议

* defer声明时刻即参数解析时刻
* defer执行结果为FILO，先进后出（越先声明的defer，执行时机越靠后）。
* 尽量不要在defer中修改返回值

## Shadow变量引发的问题

**Case-14**

```go
func main() {
	var wg sync.WaitGroup
	wg.Add(3)
	for i := 0; i < 3; i++ {
		go func() {
			defer wg.Done()
			fmt.Println(i)
		}()
	}
	wg.Wait()
}
```

<details>
<summary>打印结果是什么？</summary>
输出为3个3

这个比较常见，在for循环中，你就认为i是同一个变量，那么上例中所有gorutine共享i变量，所以打印出的值都一样。

</details>

<details>
<summary>怎么解决？</summary>
怎么解决，通过参数传递，或者创建新变量(`a := i`, 然后gorutine打印a)的方式即可

</details>



**Case-15**

```go
func main() {
    v1 := 1
    if v1 == 1 {
        v1, v2 := 2, 3
        fmt.Println("Inner:", v1, v2)
    }
    fmt.Println("Outer:", v1)
}
```

<details>
<summary>最终结果</summary>
最外层的v1依旧输出`1`

同名变量使用短声明导致`if块中的v1和外层的v1变量不是同一个`。这种问题最常见的受害者就是`err`。

</details>

### 总结

* 在相同的代码包不同作用域下的同名变量、方法之前存在屏蔽现象
* 在相同结构体内定义同名属性、方法不存在屏蔽现象（编译不过）
* 在内嵌类型和被内嵌类型之间定义的同名属性、方法存在屏蔽现象
* 在同一层级的内嵌类型之间定义同名方法、属性不存在屏蔽现象(编译不过)

## select+time.After误用

**Case-16**

```go
func main() {
	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		time.Sleep(5 * time.Second)
		cancel()
	}()
	isTimeout := false
Loop:
	for {
		select {
		case <-ctx.Done():
			break Loop
		case <-time.After(time.Second * 2):
			isTimeout = true
			break Loop
		default:
			// do sth
		}
	}
	fmt.Printf("end with timeout: %v\n", isTimeout)
}
```

<details>
<summary>输出结果是什么，这样的写法有没有问题</summary>
输出为: end with timeout: false

还会造成短时间内的内存暴涨，如果过期时间长内存会持续增张到一个很大的值。

原因：每次for循环time.After都会新建一个计时器，而这个计时器在时间到期之前gc是不会回收的
</details>

<details>
<summary>怎么改</summary>
1、使用context.WithTimeout或者context.WithDeadline

2、time.After底层会调用NewTimer(d), 在for循环外层新建一个timer，然后在select中使用新建的计时器即可

3、对于不使用但是时间又未到的计时器记得手动stop，避免因为某些情况导致短时间内内存爆增

</details>



## Go相关的检测工具

**静态检查工具 go vet**

这个工具可以协助检查`atomic`包中的函数是否使用正确、是否存在copy锁的行为和结构体标签是否使用正确等。

多说无益，建议使用vscode的各位把下面的开关打开（goland自己百度一下哈）

![](https://note.youdao.com/yws/api/personal/file/WEBba132fe2c784a6e1a32665d6b3ad1a29?method=download&shareKey=7f299aaf0f48554497b71fbbd4785771)

**代码检查工具**

![](https://note.youdao.com/yws/api/personal/file/WEBb62254c50216e1e162e1748715e50fe5?method=download&shareKey=b389745472167639a6ee84d014ec6b96)

顺便分享一下我本地的vscode配置，大家有兴趣可以自取

```json
{
    "go.autocompleteUnimportedPackages": true,
    "go.useCodeSnippetsOnFunctionSuggest": true,
    "go.useCodeSnippetsOnFunctionSuggestWithoutType": true,
    "go.useLanguageServer": true,
}
```

**数据竞争检测**

比较常用的用法如下：
```shel
go run -race pkg
go run -race *.go
go build -race main.go
```

**Goroutine泄漏检测**

目前我还没有机会用上，也希望我们永远不会有机会用上
https://github.com/uber-go/goleak

**性能分析工具**

下面的文章讲的比我好：

https://juejin.cn/post/6844904079525675016

https://blog.golang.org/pprof





# 简洁而高性能的原生网络模型


Go的原生网络模型通过在底层对epoll/kqueue/iocp的封装实现了`goroutine-per-connection`模式。在这种模式下开发者对I/O是否阻塞是无感知的，并且开发者也无需考虑gorutine甚至更底层的线程、进程的调度以及上下文切换。本次分享将通过对Go源码层层推进逐步揭开Go原生网络模型的神秘面纱。

首先我们看一下epoll的API，只涉及三个系统调用：

`epoll_create`: 创建一个epoll实例并返回实例句柄。

`epoll_ctl`: 注册file descriptor等待的I/O事件到epoll实例上。

`epoll_wait`: 阻塞监听epoll实例上所有的 file descriptor的I/O事件，它接受一个用户空间上的一块儿内存地址，内核会在I/O事件发生的时候把文件描述符列表复制到这块儿内存地址上，然后epoll_wait解除阻塞并返回，最后用户空间上的程序就可以对相应的fd进行读写了。


下面看一个简单echo服务体验一下Go的网络编程到底是有多爽。

```go

func main() {
	listen, err := net.Listen("tcp", ":2333")
	if err != nil {
		log.Println("listen error: ", err)
		return
	}
	defer listen.Close()

	for {
		conn, err := listen.Accept()
		if err != nil {
			log.Println("accept error: ", err)
			break
		}
		go echo(conn)
	}
}

func echo(conn net.Conn) {
	defer conn.Close()
	dt := make([]byte, 1024)
	// 如果没有数据读取将阻塞
	n, err := conn.Read(dt)
	if err != nil {
		log.Println("read socket error: ", err)
		return
	}
	// 如果连接不可写将阻塞
	_, _ = conn.Write(dt[:n])
}

```

监听端口只需要一个`net.Listen`方法、接受新的请求只需要一个`(Listener).Accept`方法，读写数据分别只需要`(Conn).Read`和`(Conn).Write`方法。如此简介且语义化的API让我们的编程体验极其舒适，但这些简洁的API背后都蕴含着复杂的封装。

`net.Listen("tcp", ":2333")`方法返回的`net.Listener`接口真实类型为`*net.TCPListener`, `listen.Accept`返回的`net.Conn`接口真实类型为`*net.TCPConn`。`net.TCPListener`和`net.TCPConn`都直接或者间接持有一个`*net.netFD`类型的网络描述符，而`net.Listener`的`Accept`方法和`net.Conn`的`Read/Write`方法，都是基于`net.netFD`的数据结构操作。


```go
// net/fd_posix.go
// Network file descriptor.
type netFD struct {
	pfd poll.FD

	// immutable until Close
	family      int
	sotype      int
	isConnected bool // handshake completed or use of association with peer
	net         string
	laddr       Addr
	raddr       Addr
}

// internal/poll/fd_unix.go
type FD struct {
    // 省略了很多其他字段

    // 系统文件描述符
	// System file descriptor. Immutable until Close.
	Sysfd int

	// 读写超时等操作都是通过调用pollDesc对应方法实现的
	// I/O poller.
	pd pollDesc

}

type pollDesc struct {
    // 指向runtime/netpoll.go中的pollDesc类型的指针
	runtimeCtx uintptr
}
```

## net.Listen

`net.Listen`中部分关键函数的调用路径如下。
![](https://note.youdao.com/yws/api/personal/file/WEBd0dfb27243f2e9c08f75337c130e53b6?method=download&shareKey=9c9d626b8cb4a08ad9582917c8218367)

这里需要注意的是`internal/poll/fd_poll_runtime.go`中的`runtime_pollServerInit`和`runtime_pollOpen`函数真实实现分别为`runtime/netpoll.go`中的`poll_runtime_pollServerInit`和`poll_runtime_pollOpen`函数(通过`go:linkname`将runtime中unexported的方法暴露给其他包使用)。

`poll_runtime_pollServerInit`函数内关键调用为`netpollGenericInit->runtime/netpoll_epoll.go:netpollinit`，`netpollinit`内部会调用`epollcreate1`创建一个epoll实例`epfd`,作为整个runtime的唯一event-loop使用，epoll实例创建成功后还会通过`epollctl`将相应的文件描述符注册到epoll实例中。

> 因为使用了sync.Once，整个runtime期间仅有一个epoll实例

`poll_runtime_pollOpen`函数创建一个`*runtime.pollDesc`类型的指针`pd`并通过调用`netpollopen`函数(内部会调用epollctl函数)将相应的文件描述符和`pd`地址注册到epoll实例中。


**小结**：监听某一端口时和`epoll_create`以及`epoll_ctl`这两个系统调用相关。

## (Listener).Accept

`(Listener).Accept`中部分关键函数的调用路径如下。

![](https://note.youdao.com/yws/api/personal/file/WEB4fa025c39070b6560c282ae6eaa2af78?method=download&shareKey=4705692a4ca2d3802a3199b21aaaccc1)

当正常获取到文件描述符后会调用`(*netFD).init`方法，根据前面的内容知，最后会调用`epoll_ctl`将文件描述符注册到epoll实例中。

`runtime_pollWait`实际对应`runtime/netpoll.go`中的`poll_runtime_pollWait`函数。

在正式看`poll_runtime_pollWait`函数逻辑之前，我们先看一下`runtime.pollDesc`的数据结构

```go
type pollDesc struct {
	link *pollDesc // in pollcache, protected by pollcache.lock

	// The lock protects pollOpen, pollSetDeadline, pollUnblock and deadlineimpl operations.
	// This fully covers seq, rt and wt variables. fd is constant throughout the PollDesc lifetime.
	// pollReset, pollWait, pollWaitCanceled and runtime·netpollready (IO readiness notification)
	// proceed w/o taking the lock. So closing, everr, rg, rd, wg and wd are manipulated
	// in a lock-free way by all operations.
	// NOTE(dvyukov): the following code uses uintptr to store *g (rg/wg),
	// that will blow up when GC starts moving objects.
	lock    mutex // protects the following fields
	fd      uintptr
	closing bool
	everr   bool      // marks event scanning error happened
	user    uint32    // user settable cookie
	rseq    uintptr   // protects from stale read timers
	rg      uintptr   // pdReady, pdWait, G waiting for read or nil
	rt      timer     // read deadline timer (set if rt.f != nil)
	rd      int64     // read deadline
	wseq    uintptr   // protects from stale write timers
	wg      uintptr   // pdReady, pdWait, G waiting for write or nil
	wt      timer     // write deadline timer
	wd      int64     // write deadline
	self    *pollDesc // storage for indirect interface. See (*pollDesc).makeArg.
}
```

其中最值得关注的是`rg`和`wg`，其取值可能是状态也可以等待i/o就绪的groutine指针。

而`poll_runtime_pollWait`函数的逻辑如下:

```go
func poll_runtime_pollWait(pd *pollDesc, mode int) int {
	errcode := netpollcheckerr(pd, int32(mode))
	if errcode != pollNoError {
		return errcode
	}
	// As for now only Solaris, illumos, and AIX use level-triggered IO.
	if GOOS == "solaris" || GOOS == "illumos" || GOOS == "aix" {
		netpollarm(pd, mode)
	}
	// 进入netpollblock并且判断是否有期待的 I/O 事件发生
	// 此处for循环是为了一直等待io ready
	for !netpollblock(pd, int32(mode), false) {
		errcode = netpollcheckerr(pd, int32(mode))
		if errcode != pollNoError {
			return errcode
		}
		// Can happen if timeout has fired and unblocked us,
		// but before we had a chance to run, timeout has been reset.
		// Pretend it has not happened and retry.
	}
	return pollNoError
}

func netpollblock(pd *pollDesc, mode int32, waitio bool) bool {
	gpp := &pd.rg
	if mode == 'w' {
		gpp = &pd.wg
	}

	// set the gpp semaphore to pdWait
	// 这个 for 循环是为了等待 io ready 或者将状态设置为io wait
	for {
		old := *gpp
		if old == pdReady {
			*gpp = 0
			return true
		}
		if old != 0 {
			throw("runtime: double wait")
		}
		if atomic.Casuintptr(gpp, 0, pdWait) {
			break
		}
	}

	// waitio此时为false，并且pollDesc一般都是正常的，所以会调用gopark将当前的goroutine
	// park住，直到对应的fd上发生可读/可写或者其其他i/o事件
	// 在gopark内部会将当前的gorutine指针赋值给gpp(pollDesc.rg/pollDesc.wg) 
	// 同时将gorutine状态置为waiting
	// 后需当io就绪后取出注册到epoll实例中的数据pollDesc，并将pollDesc中等待i/o的g
	// 放回调度链表重新调度
	if waitio || netpollcheckerr(pd, mode) == 0 {
		gopark(netpollblockcommit, unsafe.Pointer(gpp), waitReasonIOWait, traceEvGoBlockNet, 5)
	}
	// be careful to not lose concurrent pdReady notification
	old := atomic.Xchguintptr(gpp, 0)
	if old > pdWait {
		throw("runtime: corrupted polldesc")
	}
	return old == pdReady
}

```

**小结**：
1. 获取到文件描符述时，会通过系统调用`epoll_ctl`将文件描述符注册到epoll实例中
2. 如果没有i/o事件时，会调用gopark将gorutine指针保存，并将gorutine状态置为waiting。

## (Conn).Read & (Conn).Write

`(Conn).Read`和`(Conn).Write`原理类似，这里仅分享`(Conn).Read`的逻辑。

![](https://note.youdao.com/yws/api/personal/file/WEBacd905c99ad4d7169fc0a298c9b75c22?method=download&shareKey=3090cdec976aeef3ea6dfedc655b0a14)

参考前文，我们知道调用`(*pollDesc).waitRead`时，因为没有可读的数据则gorutine会被park住直到有i/o事件发生时才恢复执行。

## runtime的完美配合

到这里，前文的echo服务核心代码基本分析完毕。gorutine如何阻塞我们也已经明白，但何时恢复执行却还是一头雾水，而这就是本小节的重点。

前文中只出现了`epoll_create`和`epoll_ctl`，还缺少`epoll_wait`的系统调用。以linux为例，调用`runtime/netpoll_epoll.go:netpoll`函数时会调用`epollwait`。

```go
func netpoll(delay int64) gList {
    // 省略代码
	var events [128]epollevent
retry:
    // 无阻塞查看epoll实例上是否i/o就绪的fd
	n := epollwait(epfd, &events[0], int32(len(events)), waitms)
	// 省略代码
	// 存储要恢复的 goroutines，最后返回给调用方
	var toRun gList
	for i := int32(0); i < n; i++ {
		ev := &events[i]
		if ev.events == 0 {
			continue
		}
		// 省略代码
		// 判断发生的事件类型，读类型或者写类型等，然后给 mode 复制相应的值，
        // mode 用来决定从 pollDesc 里的 rg 还是 wg 里取出 goroutine
		var mode int32
		if ev.events&(_EPOLLIN|_EPOLLRDHUP|_EPOLLHUP|_EPOLLERR) != 0 {
			mode += 'r'
		}
		if ev.events&(_EPOLLOUT|_EPOLLHUP|_EPOLLERR) != 0 {
			mode += 'w'
		}
		if mode != 0 {
		    // 取出保存在 epollevent 里的 pollDesc
			pd := *(**pollDesc)(unsafe.Pointer(&ev.data))
			pd.everr = false
			if ev.events == _EPOLLERR {
				pd.everr = true
			}
			// 调用 netpollready，传入就绪 fd 的 pollDesc，
            // 把 fd 对应的 goroutine 添加到链表 toRun 中
			netpollready(&toRun, pd, mode)
		}
	}
	return toRun
}
```
`netpoll`在以下两个场景会被调用。

首先，runtime在做gorutine调度时会检查已经就绪的文件描述符并恢复相应的gorutine为可执行状态从而参与调度执行。

具体调用链路为`runtime.schedule()->runtime.findrunable()->runtime.netpoll()`。

其次，`sysmon`监控线程会在循环过程中检查距离上一次`runtime.netpoll`被调用是否超过了10ms。如果超过10ms，则调用它拿到可运行的gorutine列表并通过`injectglist`把g列表放入全局队列或者当前P本地队列等待被执行。

> Go runtime 在程序启动的时候会创建一个独立的 M 作为监控线程，叫sysmon ，这个线程为系统级的daemon线程，无需P即可运行， sysmon每 20us~10ms 运行一次

## 总结

1、client连接server时，listener通过accept调用接受新的connection，每一个新的connection都启动一个goroutine处理，accept调用会把该connection的文件描述符注册到epoll的监听列表

2、当gorutine调用`conn.Read`或者`conn.Write`等需要阻塞等待的函数时，会被gopark将当前gorutine置为等待状态同时将gorutine地址存入`pollDesc`。

3、runtime在循环调度的`runtime.schedule()`函数以及`sysmon`监控线程中调用`runtime.nepoll`以获取可运行的goroutine列表并通过`injectglist`把剩下的g放入调度队列等待重新执行。

## 问题

Go netpoller的设计不可谓不精巧、性能也不可谓不高，配合goroutine开发网络应用的时候就一个字：爽。因此Go的网络编程模式是及其简洁高效的，然而，没有任何一种设计和架构是完美的， `goroutine-per-connection`这种模式虽然简单高效，但是在某些极端的场景下也会暴露出问题：goroutine虽然非常轻量，它的自定义栈内存初始值仅为2KB，后面按需扩容；海量连接的业务场景下， `goroutine-per-connection`，此时goroutine数量以及消耗的资源就会呈线性趋势暴涨，虽然Go scheduler内部做了g的缓存链表，可以一定程度上可缓解高频创建和销毁goroutine的压力，但是对于`瞬时性暴涨的长连接场景就无能为力了`，大量的goroutines会被不断创建出来侵占系统资源，然后资源被侵占又反过来影响Go的调度，进而导致性能下降。

# 资源分享

## 天天向上资料分享

**知识图谱**:
https://www.processon.com/view/link/5a9ba4c8e4b0a9d22eb3bdf0#map

**CodeReview**:
https://github.com/golang/go/wiki/CodeReviewComments

**项目布局（这个参考一下就行了还需因地制宜）**:
https://github.com/golang-standards/project-layout

**最新的官方Q&A**:
https://stackoverflow.com/collectives/go

**官方博客**:
https://blog.golang.org/index

**官方文档**:
https://golang.org/doc/

**我十分推荐的一个大神**:
https://draveness.me/golang/

**包百科全书（想找一些好用的包可以来这里翻一番）**:
https://github.com/avelino/awesome-go


## 装逼工具分享

**mac便捷的工具**:
https://github.com/nikitavoloboev/my-mac-os

**chrome插件推荐**
* FeHelper
* Vimium
* 彩云小译 

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)