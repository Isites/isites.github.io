---
title: "【重要】这个布谷鸟的库有一个坑，请尽快更新！"
date: 2022-03-14T08:38:00+08:00
draft: true
toc: true
images:
tags:
  - Go
---

有没有，存不存在？这是一个很经典的场景，几乎每一位互联网开发者都遇到过。其对应的解决方案也比较多。布谷鸟过滤器就是其中一种十分流行的方案。

当然，本篇并不是来介绍布谷鸟过滤器的原理，而是记录一个老许在使用一个布谷鸟过滤器开源库时遇到的坑。如果有读者和老许使用了相同的开源库，请及时更新最新的代码以避免线上panic。当然，如果是自实现的布谷鸟过滤器，老许愿称你为：

![](https://note.youdao.com/yws/api/personal/file/WEB5245ec2c28aa600bc8823001d690598a?method=download&shareKey=31f2c3ae98a69926b16e9c1a893c7db8)

其他废话不多说，我们来看一下这个开源库和坑分别是什么。

**开源库**：

https://github.com/seiflotfy/cuckoofilter

**坑**：

```go
func TestService_getInstalledApps(t *testing.T) {
    // 从缓存或者其他地方取出布谷鸟过滤器的数据，解析得到布谷鸟过滤器实例
    c, err := cuckoo.Decode([]byte(""))
    assert.Nil(t, err)
    // 查询 test 是否存在
    assert.False(t, c.Lookup([]byte("test")))
}
```

上面这个单元测试是无法正常运行的，其结果如下：

```
--- FAIL: TestService_getInstalledApps (0.00s)
panic: runtime error: index out of range [3532051776] with length 0 [recovered]
    panic: runtime error: index out of range [3532051776] with length 0

goroutine 19 [running]:
testing.tRunner.func1.2({0x102e36060, 0x140000e4240})
    /usr/local/go/src/testing/testing.go:1209 +0x258
testing.tRunner.func1(0x140000fe680)
    /usr/local/go/src/testing/testing.go:1212 +0x284
panic({0x102e36060, 0x140000e4240})
    /usr/local/go/src/runtime/panic.go:1038 +0x21c
```

根据上面的单元测试，我们下面分别看一看`Decode`和`Lookup`函数。

**Decode函数**

```go
// Decode returns a Cuckoofilter from a byte slice
func Decode(bytes []byte) (*Filter, error) {
    var count uint
    if len(bytes)%bucketSize != 0 {
        return nil, fmt.Errorf("expected bytes to be multiple of %d, got %d", bucketSize, len(bytes))
    }
    buckets := make([]bucket, len(bytes)/4)
    for i, b := range buckets {
        for j := range b {
            index := (i * len(b)) + j
            if bytes[index] != 0 {
                buckets[i][j] = fingerprint(bytes[index])
                count++
            }
        }
    }
    return &Filter{
        buckets:   buckets,
        count:     count,
        bucketPow: uint(bits.TrailingZeros(uint(len(buckets)))),
    }, nil
}
```

首先，检查输入是否为`bucketSize`的倍数，如果不是则输入不合法，如果是则构建布谷鸟实例。然而，这里有一个隐含条件是空字符串的长度一定是`bucketSize`的倍数，这也就导致构建的布谷鸟实例中`buckets`的长度为`0`，同时也为后续的panic埋下了伏笔。

> 这里额外提一句，`bits.TrailingZeros`函数在[惊！Go里面居然有这样精妙的小函数！](https://mp.weixin.qq.com/s/_zqSPvpUdeInUiE-DVeGmg)中提到过，其作用是返回输入值最低位为0的个数。所以，输入值为`0`时，则返回值为`32`或者`64`。

**Lookup函数**

```go
// Lookup returns true if data is in the counter
func (cf *Filter) Lookup(data []byte) bool {
    i1, fp := getIndexAndFingerprint(data, cf.bucketPow)
    if cf.buckets[i1].getFingerprintIndex(fp) > -1 {
        return true
    }
    i2 := getAltIndex(fp, i1, cf.bucketPow)
    return cf.buckets[i2].getFingerprintIndex(fp) > -1
}
```

上面代码中`getIndexAndFingerprint`函数返回需要使用的`bucket`索引和指纹。而根据前文知`buckets`长度为`0`，所以你的`i1`值无论是什么必定会因为`cf.buckets[i1]`的调用而造成panic。

以上，就是这个布谷鸟开源库的一个坑！要解决这个坑也很简单，只需要在检测到输入为空时返回不合法的错误即可。万万没想到，这个坑如此简单，那么这个pr老许我要定了！

https://github.com/seiflotfy/cuckoofilter/pull/46

![](https://note.youdao.com/yws/api/personal/file/WEBdba62e7cf95394242dc8ef67820f25b3?method=download&shareKey=2d5f133405a124f68d95c117d4d4fbd3)

该开源库最新的代码已合入老许的改动，请使用该开源库的同学及时更新代码。

最后，衷心希望本文能够对各位读者有一定的帮助。

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)