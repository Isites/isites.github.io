---
title: "sync.Once化作一道光让我顿悟"
date: 2021-09-20T12:20:38+08:00
draft: true
toc: true
images:
tags:
  - Go
---


前几天和公司同事吃饭直接社死，同事直言我写的文章很骚。

![](https://note.youdao.com/yws/api/personal/file/WEB42049ac1e6f622a5c4f922a8d281b50b?method=download&shareKey=03ed8c0a8c01be952c3be942bc6a562e)

他们怎么知道我在写公众号！

我tm没在公众号里写什么奇奇怪怪的东西吧！

求求不要让公司更多同事知道这件事了！

大地为什么还没有裂开一条缝...


当时的心情历历在目，而老许此刻写下的文字却是另外一种想法。肤浅！简直太肤浅了！不要只浮于文字本身的魅力，请多关注老许分享的知识点（手动狗头）。另外一方面，老许觉得他们通过文章对我的认知有违我在公司树立的老实本分人设，但请不要奇怪也不要声张，毕竟我就是大部分程序员的缩影——“沉默寡言，心有一片海”。

我们高中物理老师常说，透过现象看本质，所以形式不重要，重要的是我想分享什么。这还要从一段有并发问题的代码说起（下面为公司部分源码简化后的模拟例子）。


```go
type test struct {
	fff string
}

var resource *test

func doSomething() error {
    if test == nil {
        n, e := rand.Int(rand.Reader, big.NewInt(3))
        // 通过随机数模拟发生错误
		if e != nil || n.Int64() > 0 {
		    retur fmt.Errorf("random [%w] err(%d)", e, n.Int64())
		}
		// 未发生错误，则赋值
		resource = &test{"关注公众号：Gopher指北"}
    }
    // do something
    return nil
}

```
老许微微一笑，这道题我会，反手利用`sync.Once`一顿改造。

```go
var (
	resource *test
	loadOnce sync.Once
)

func doSomething() error {
    var err error
	loadOnce.Do(func() {
		n, e := rand.Int(rand.Reader, big.NewInt(3))
		// 通过随机数模拟发生错误
		if e != nil || n.Int64() > 0 {
			err = fmt.Errorf("random [%w] err(%d)", e, n.Int64())
			return
		}
		// 未发生错误，则赋值
		resource = &test{"关注公众号：Gopher指北"}
	})
	if err != nil {
		// 如果因为某些原因导致初始化失败，则重新赋值以便可以重入
		loadOnce = sync.Once{}
		return err
	}
	// double check
	if resource == nil {
		return fmt.Errorf("assign failed")
	}
	// do something
	return err
}
```

写下这段代码时，老许一顿沾沾自喜：

* `sync.Once`底层通过`defer`标记初始化完成，所以无论初始化是否成功都会标记初始化完成，即不可重入。上面的代码老许通过重新赋值的方式保证`sync.Once`可重入。

* `G1`和`G2`同时执行时，`G1`执行失败后，`G2`不会执行初始化逻辑，因此需要`double check`。

不知道你们有没有经历过，很多时候在一个问题上思考良久，还不如去上一次厕所突然得到的方案来的巧妙。本次依旧如此，在改造完这段代码的当晚躺在床上休息时，脑中灵光一闪，有问题！

* `sync.Once`通过赋值新变量的方式保证可重入，但也正因为如此`loadOnce`存在同时读写的并发问题，而且`sync.Once`内部使用`Mutex`不能复制。

* `double check`部分的逻辑和初始化的复制逻辑存在读写并发问题。

夜深人静思考时，就是这一次犯错，也是这一次灵光一闪，让我思考良多，关于思考的内容稍后缓缓到来。

知道了问题和目标解决起来就容易多了。

**可重入且并发安全的sync.Once**

```go
// 基本结构和官方sync.Once完全一致
type IOnce struct {
	done uint32
	m    sync.Mutex
}
// Do方法传递的函数增加一个error返回值
func (o *IOnce) Do(f func() error) {
	if atomic.LoadUint32(&o.done) == 0 {
		o.doSlow(f)
	}
}

// 不使用defer控制don标识，而通过也无妨的返回值来控制
func (o *IOnce) doSlow(f func() error) {
	o.m.Lock()
	defer o.m.Unlock()
	if o.done == 0 {
		if f() != nil {
			return
		}
		// 执行成功后才将done置为1
		atomic.StoreUint32(&o.done, 1)
	}
}

```
**最终版代码**

```go
var (
	resource *test
	ionce IOnce
)

func doSomething() error {
    var err error
    ionce.Do(func() error {
		n, e := rand.Int(rand.Reader, big.NewInt(3))
		// 通过随机数模拟发生错误
		if e != nil || n.Int64() > 0 {
			err = fmt.Errorf("random [%w] err(%d)", e, n.Int64())
			return err
		}
		resource = &test{"关注公众号：Gopher指北"}
		return nil
	})
	// do something
	return err
}


```

其实不只老许魔改过`sync.Once`，老许还在github上面看到过另一个魔改版本（很遗憾现在已经不记得是哪个仓库了无法贴出地址）。

```go
func (o *Once) doSlow(f func()) {
	o.m.Lock()
	defer o.m.Unlock()
	if o.done == 0 {
	    atomic.StoreUint32(&o.done, 1)
		f() 
	}
}
```
和官方实现的版本相比，仅仅是将`defer atomic.StoreUint32(&o.done, 1)`修改为`atomic.StoreUint32(&o.done, 1)`，老许推测此实现是想尽可能早的返回，避免锁的竞争，但是目前尚未发现适用场景所以记忆深刻。

前面内容并不复杂，但它确确实实给老许提了个醒，让老许有了下面一段感悟。

回成都之后深刻感受到了这个新一线城市的忙碌，很多时候都是时间紧任务重，而我受周围氛围和环境的影响渐渐丢失了一份"不急不缓，不骄不躁，回归本心"的态度。有位读者曾经告诉我“世界那么大，你才看到多少”。当老许看到这个留言时犹如当头棒喝，余生那么长，世界那么大，我们有什么好着急的又何须给自己那么大的压力（再次感谢这位读者～）。

![](https://note.youdao.com/yws/api/personal/file/WEBf21418759ed0be65e748ee41f3ca9d11?method=download&shareKey=26d3e2d6de1dcdce4c6c1f5b5672731a)

人都容易受周围环境的影响，我也不例外，明明之前已经下定决心兼顾生活和工作缓步前行。以这次`sync.Once`事件为例，如果我能稍微思考一下也许就不会出现本不该出现的失误。对我们做技术的人来说，学习是一场长达一生的持久战，有的人行的快，有的人行的慢，坚持且松弛有度，不骄不躁，多思考才是我们能够走的远走的久的根本。

步子迈的太大，容易扯到蛋，步子迈的太快，灵魂容易跟不上。老许只希望自己在接下来的生活、学习和工作中戒骄戒燥放缓脚步坚定前行，至少一定要带着脑子工作和生活，不要让繁重的事务挤掉了思考的时间。

> 这是一篇参杂少量知识点的技术人感悟水文，希望老许对自己的反思能够帮到各位读者，也欢迎有兴趣的读者后台留言交流。

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)