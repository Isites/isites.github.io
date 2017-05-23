---
layout: post
title: vueRouter断章取义
categories: js
---

### 重定向和别名

#### 重定向

重定向也是通过`routes`配置来完成的, 下面的列子是从`/a`重定向到`/b`:

```javascript
const router = new VueRouter({
  routes: [
    {path: '/a', redirect: '/b'}
  ]
})
```

重定向的目标也可以是一个命名的路由:

```javascript
const router = new VueRouter({
  routes: [
    {path: '/a', redirect: {name: 'foo'}}
  ]
})
```

甚至是一个方法, 动态返回重定向目标

```javascript
const = new VueRouter({
  routes: [
    {path: '/a', redirect: to => {
      //方法接受 目标路由作为参数
      //return 重定向的 字符串路径/路径对象
    }}
  ]
})
```

#### 别名

[重定向]的意思是当用户方`/a`时, URL将会被替换成`/b`, 然后匹配路由为`/b`, 那么[别名]是什么呢.

**/a的别名是/b, 意味着, 当用户访问/b时, url会保持为/b, 单路由匹配则为/a, 就像用户访问/a一样**.

上面对应的路由配置为:

```javascript
const router = new VueRouter({
  routes: [
    {path: '/a', component: A, alias: '/b'}
  ]
})
```

#### 导航钩子

> 正如其名, `vue-router`提供的导航钩子主要用来拦截导航, 让它完成跳转或取消. 有多种方式可以再路由导航发生时执行钩子: 全局的, 单个路由独享的, 或者组件级的

#### 全局钩子

你可以使用`router.beforeEach`注册一个全局的`before`钩子:

```javascript
const router = new VueRouter({});
router.beforeEach((to, from, next) => {
  //
})
```

当一个导航触发时, 全局的`before`钩子按照创建顺序第啊用钩子是异步解析执行, 此时导航在所有钩子resolve完成之前一直处于等待中.

每个钩子方法接受是哪个参数:

* **to**: **Route**即将要进入的目标路由对象
* **from**: **Route** 当前导航正要离开的路由
* **next**: Function:一定要调用该方法来resolve这个钩子. 执行效果依赖next方法的低啊用参数.
  * **next()**:进行管道中的下一个钩子．　如果全部钩子执行完了，　则导航的状态就是confirmed(确认的)
  * **next(false)**: 中断当前的导航. 如果浏览器的url改变了(可能是用户手动或者浏览器后退按钮),  那么url地址会重置到from路由对应的地址
  * **next('/')或者next({path: '/'})** : 跳转到一个不同的地址. 当前的导航被中断, 然后进行一个新的导航

**确保要调用next()方法, 否则钩子就不会被resolved**

同样可以注册一个全局的after钩子, 不过它不想before钩子那样, after钩子没有next方法, 不能改变导航:

```javascript
router.afterEach(route => {
  
})
```

#### 某个路由独享的钩子

你可以在路由配置上直接定义beforeEnter钩子:

```javascript
const router = new VueRouter({
  routes: [
    {
      path: '/foo',
      component: Foo,
      beforeEnter: (to, from, next) => {
        // ...
      }
    }
  ]
})
```

这些钩子与全局before钩子的参数是一样的

#### 组件内钩子

最后, 你可以在路由组件内直接定义一下路由导航钩子:

* beforeRouteEnter
* beforeRouteUpdate(2.2新增)
* beforeRouteLeave

```javascript
const Foo = {
  template: '',
  beforeRouteEnter (to, from, next) {
    //在渲染该组件的对应路由被confirm前调用
    //不能获取组件实例 `this`, 因为钩子执行前, 组件实例还没被创建
  },
  beforeRouteUpdate (to, from, next) {
    // 在当前路由改变, 但是组件被复用是调用
    //举例来说, 对于一个带有动态参数的路径 /fll/:id, 在foo/1 和foo/2之间跳转的时候, 
    //由于会渲染同样的foo组件, 因此组件实例会被复用,而这个钩子就会在这种情况下被调用
    //可以访问组件实例 this
  },
  beforeRouteLeave (to, from, next) {
    //导航离开该组件的对应路由时调用
    // 可以访问组件实例, this
  }
}
```

`beforeRouteEnter`钩子不能访问`this`, 但是你可以通过传一个而回调给`next`来访问组件实例. 在导航被确认的时候执行回调, 并且把组件实例作为回调方法的参数

```javascript
beforeRouteEnter (to, from, next) {
  next (vm => {
    //通过vm 访问组件实例
  })
}
```

### 路由元信息

定义路由的时候可以配置meta字段:

```javascript
const router = new VueRouter({
  routes: [
    path: '/foo',
    component: Bar,
    meta: {requiresAut: true}
  ]
})
//使用方法如下
```

首先, 我们称呼`routes`配置中的每个路由对象为路由记录. 路由记录可以是嵌套的, 因此, 当一个路由匹配成功后, 他可能匹配多个路由记录

例如, 根据上面的路由配置, `/foo/bar`这个url将会匹配父路由记录以及子路由记录

一个路由匹配到的所偶有路由记录会暴露为`$route`对象(还有在导航钩子中的route对象)的`$route.matched`数组, 因此, 我们需要遍历`$route.matched`来检查路由记录中的`meta`字段

```javascript
router.beforeEach((to, from, next) => {
  if (to.matched.some(record => record.meta.requiresAuth)) {
    // this route requires auth, check if logged in
    //if not, redirect to login page
    if (!auth.loggedIn()) {
      next({
        path: '/login',
        query: {redirect: to.fullPath}
      })
    } else {
      next()
    }
  } else {
    next() // 确保一定要调用next()
  }
})
```

[参考](https://router.vuejs.org/zh-cn/advanced/data-fetching.html)