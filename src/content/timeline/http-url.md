---
title: "URL中的空格、加号究竟应该使用何种方式编码"
date: 2021-10-10T12:20:38+08:00
draft: true
toc: true
images:
tags:
  - 网络篇
---



URL中不能显示地包含空格这已经是一个共识，而空格以何种形式存在，在不同的标准中又不完全一致，以致于不同的语言也有了不同的实现。

`rfc2396`中明确表示空格应该被编码为`%20`。

![](https://note.youdao.com/yws/api/personal/file/WEBaa22f5efec41ec872796c23371f784ac?method=download&shareKey=38a9fcb1344fcd1db67962dca0d5f5c7)

而W3C的标准中却又说空格可以被替换为`+`或者`%20`。

![](https://note.youdao.com/yws/api/personal/file/WEB940ba3ff5f42c0b5fe91a08aafd9e20d?method=download&shareKey=68e4496f0ceab247e709bfe1d1a116b1)

老许当场懵逼，空格被替换为`+`，那`+`本身只能被编码。既然如此，为什么不直接对空格进行编码呢。当然这只是老许心中的疑惑，以前的背景我们已经无法追溯，已成的事实我们也无法改变。但，空格到底是被替换为`+`还是`20%`，`+`是否需要被编码都是现在的我们需要直面的问题。

# Go常用的三种URL编码方式
作为Gopher最先关注的自然是Go语言本身的实现，因此我们首先了解一下Go中常用的三种URL编码方式的异同。
## url.QueryEscape
```go
fmt.Println(url.QueryEscape(" +Gopher指北"))
// 输出：+%2BGopher%E6%8C%87%E5%8C%97
```

使用`url.QueryEscape`编码时，空格被编码为`+`，而`+`本身被编码为`%2B`。

## url.PathEscape

```go
fmt.Println(url.PathEscape(" +Gopher指北"))
// 输出：%20+Gopher%E6%8C%87%E5%8C%97
```

使用`url.PathEscape`编码时，空格被编码为`20%`, 而`+`则未被编码。

## url.Values

```go
var query = url.Values{}
query.Set("hygz", " +Gopher指北")
fmt.Println(query.Encode())
// 输出：hygz=+%2BGopher%E6%8C%87%E5%8C%97
```

使用`(Values).Encode`方法编码时，空格被编码为`+`，而`+`本身被编码为`%2B`，进一步查看`(Values).Encode`方法的源码知其内部仍旧调用`url.QueryEscape`函数。而`(Values).Encode`方法和`url.QueryEscape`的区别在于前者仅编码query中的key和value，后者会对`=`、`&`均进行编码。

对我们开发者而言，这三种编码方式到底应该使用哪一种，请继续阅读后文相信你可以在后面的文章中找到答案。

# 不同语言中的实现

既然空格和`+`在Go中的URL编码方式有不同的实现，那在其他语言中是否也存在这样的情况呢，下面以PHP和JS为例。
## PHP中的URL编码

**urlencode**

```php
echo urlencode(' +Gopher指北');
// 输出：+%2BGopher%E6%8C%87%E5%8C%97
```

**rawurlencode**
```php
echo rawurlencode(" +Gopher指北");
// 输出：%20%2BGopher%E6%8C%87%E5%8C%97
```

PHP的`urlencode`和Go的`url.QueryEscape`函数效果一致，而`rawurlencode`则将空格和`+`均进行编码。


## JS中的URL编码

**encodeURI**
```javascript
encodeURI(' +Gopher指北')
// 输出：%20+Gopher%E6%8C%87%E5%8C%97
```

**encodeURIComponent**
```javascript
encodeURIComponent(' +Gopher指北')
// 输出：%20%2BGopher%E6%8C%87%E5%8C%97
```
JS的`encodeURI`和Go的`url.PathEscape`函数效果一致，而`encodeURIComponent`则将空格和`+`均进行编码。

# 我们应该怎么做

## 更推荐使用url.PathEscape函数编码

在前文中已经总结了`Go`、`PHP`和`JS`对` +Gopher指北`的编码操作，下面总结一下其对应的解码操作是否可行的二维表。

|编码/解码|url.QueryUnescape|url.PathUnescape|urldecode|rawurldecode|decodeURI|decodeURIComponent|
|:----|:----|:----|:----|:----|:----|:----|
|url.QueryEscape|Y|N|Y|N|N|N|
|url.PathEscape|N|Y|N|*YY*|Y|*YY*|
|urlencode|Y|N|Y|N|N|N|
|rawurlencode|Y|*YY*|Y|Y|N|Y|
|encodeURI|N|Y|N|Y|Y|Y|
|encodeURIComponent|Y|*YY*|Y|Y|N|Y|

上表中的`YY`和`Y`同含义，老许仅以`YY`表示在Go中推荐使用`url.PathEscape`进行编码，同时在PHP和JS中分别推荐使用`rawurldecode`和`decodeURIComponent`进行解码。

在实际的开发过程中，Gopher一定会存在需要解码的场景，此时就需要和URL编码方进行沟通以得到合适的方式解码。

## 对值进行编码

那有没有通用的不需要URL编解码的方式呢？毫无疑问是有的！以`base32`编码为例，其编码字符集为`A-Z和数字2-7`，此时对值进行base32编码后就无需url编码了。


最后，衷心希望本文能够对各位读者有一定的帮助。

> 本文使用环境分别为`PHP 7.3.29`、`go 1.16.6`和`js Chrome94.0.4606.71的Console`

**参考**

* https://www.rfc-editor.org/rfc/rfc2396.txt
* https://www.w3schools.com/tags/ref_urlencode.ASP


【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)