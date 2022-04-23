---
title: "现在，这个酷炫的github首页是你们的了！"
date: 2022-04-11T08:38:48+08:00
draft: true
toc: true
images:
tags:
  - 杂谈
---

装逼方法千千万，guthub占一半。几乎每一位求职者都乐意在简历中贴上自己的github地址。事情的起源也是因为我最近查看候选人简历上的github时，发现其首页酷炫无比。既然被我发现，那现在我也拥有一个酷炫的首页了！

正所谓“吃水不忘挖井人”，用了别人的东西不提一嘴是不合适的。这个酷炫的github首页，我基本没做什么额外的工作，完全依靠各位巨人，尤其要感谢下面两篇文章。

https://blog.holic-x.com/wv-blog/post/7ad96a5d.html

https://github.com/anuraghazra/github-readme-stats/blob/master/docs/readme_cn.md

接下来我们分步骤开始构建一个酷炫的github首页。首先，创建一个和github用户名同名的仓库。以老许的为例，创建同名仓库时会有如下提示，看到这个提示也就证明我们从0走到了1。

![](https://note.youdao.com/yws/api/personal/file/WEB46682e1f91bd5544750ffd60f12900bf?method=download&shareKey=4c236b54935c3f6897012a46cd070b75)

仓库创建好了之后，我们只需要编辑`README.md`，其内容将会展示在github首页。常规的文字编辑老许就不多bb了，我们直奔主题想办法让其酷炫起来。

## GitHub统计卡片

前人栽树后人乘凉，最常规最简单的统计卡片生成只需要使用如下代码即可（将`${username}`替换为自己的github用户名）。

```go
![](https://github-readme-stats.vercel.app/api?username=${username})
```

卡片还有很多别的参数可以定义，老许就不一一阐述，这里直接贴上我的自定义参数`count_private=true&show_icons=true&theme=github`。其展示效果如下。

![](https://note.youdao.com/yws/api/personal/file/WEBc0874331dc489fc788f8fa9bac6fd7ce?method=download&shareKey=62c02cdaa8f5a6208336c596b09caf85)

## 热门语言卡片

热门语言卡片使用方式同样简单，只需要使用如下代码即可（将`${username}`替换为自己的github用户名）。

```go
![](https://github-readme-stats.vercel.app/api/top-langs/?username=${username})
```

同样，老许也根据自己情况增加了自定义参数`hide=Java,HTML,PHP&layout=compact&theme=github`，其展示效果如下。

![](https://note.youdao.com/yws/api/personal/file/WEB6b532a117aecde7a6b4c98191ed0c7dc?method=download&shareKey=f4fdee332141e179e52e7726dfedd320)

## GitHub活动统计图

GitHub活动统计图使用如下代码即可(将`${username}`替换为自己的github用户名)。

```go
![](https://activity-graph.herokuapp.com/graph?username=${username})
```

为了能够和GitHub统计卡片以及热门语言卡片表现更加统一，老许增加了自定义参数`theme=github-light`，其展示效果如下。

![](https://note.youdao.com/yws/api/personal/file/WEB0a165b43f87948fb3a27750a98b20693?method=download&shareKey=ac4c563fa64d4d8533a63b0b20f26e3a)

最终，老许的github首页展示效果如下。

![](https://note.youdao.com/yws/api/personal/file/WEB202e85786d0a1c5293dc4e5970c32128?method=download&shareKey=2ebcdfd1b503fdbbe336d5876a7f40ba)

为了能够让各位读者把我的首页变成你们自己的首页，欢迎访问老许的github(https://github.com/Isites)借鉴。

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)
