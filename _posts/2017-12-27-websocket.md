---
layout: post
title: websocket学习
categories: js
---

### 初识websocket

WebSocket API是下一代客户端-服务器的异步通信方法. 该通信取代了单个TCP套接字, 使用ws或wss协议, 可用于任意的客户端和服务器程序. WebSocket目前由W3C进行标准化. WebSocket已经受到很多浏览器支持

### websocket api的用法

客户端的api, 下面的代码片段是打开一个连接, 为连接创建事件监听器, 断开连接, 消息时间, 发送消息返回到服务器, 关闭连接:

```javascript
//创建一个socket实例
var socket = new WebSocket('ws://localhost:8080')
//打开socket
/**
 * 实例对象的onopen属性, 用于指定连接成功后的回调函数
 * 如果要指定多个回调函数, 可以使用addEventListener方法, 此方法可以为on系列事件添加多个回调
 * socket.addEventListener('open', function (event) {})
*/
socket.onopen = function(event) {
  //发送一个初始化消息
  socket.send('I am the client and I\m listening')
  //发送blob对象的列子
  var file = document.querySelector('input[type="file"]')
  socket.send(file)
}
//监听消息, 用于指定收到服务器数据后的回调函数
/**
 * 注意, 服务器数据可能是文本, 也可能是二进制数据(blob对象或ArrayBuffer对象)
*/
socket.onmessage = function(event) {
  console.log('client received a message', event)
  if(typeof event.data === String) {
    console.log("received data string")
  }
  if(event.data instanceof ArrayBuffer) {
    console.log("received arraybuffer")
  }
}
/**
 * 除了动态判断收到的数据类型, 也可以使用binarayType属性, 显示指定收到的二进制数类型
 * socket.binaryType = "blob"
 * socket.binaryType = "arraybuffer"
*/
/**
 * 实例对象的onclose属性, 用于指定连接关闭后的回调函数
 * 如果要指定多个回调函数, 使用addEventListenner方法
*/
socket.onclose = function(event) {
  console.log('Connection closed')
}

```

### websocket.readyState

> * CONNECTING:　值为０, 表示正在连接
> * OPEN: 值为1, 表示连接成功, 可以通信了
> * CLOSING: 值为2, 表示连接正在关闭
> * CLOSED: 值为3, 表示连接已经关闭, 或者打开连接失败

### websocket.bufferedAmount

实例对象的bufferedAmount属性, 表示还有多少字节的二进制数据没有发送出去, 它可以用来判断发送是否结束

```javascript
var data = new ArrayBuffer(100000)
socket.send(data)
if(socket.bufferedAmount === 0){
  //发送完毕
} else {
  //发送还没有结束
}
```

### websocket.onerror

实例对象的onerror属性, 用于指定报错是的回调函数

```javascript
socket.onerror = function(event) {
  //handle error event
}
```

### 服务器端的实现

常用的node实现有

- [µWebSockets](https://github.com/uWebSockets/uWebSockets)
- [Socket.IO](http://socket.io/)


- [WebSocket-Node](https://github.com/theturtle32/WebSocket-Node)

> 一款有意思的websocket服务器, 它的最大特点是, 就是后台脚本不限语言, 标准输入就是websocket的输入, 标准输出就是websocket的输出

eg.

```javascript
process.stdin.setEncoding('utf8')
process.stdin.on('readable', function() {
  var chunk = process.stdin.read()
  if (chunk !== null) {
    process.stdout.write('data:' + chunk)
  }
})
```

启动

```sh
websocketd --port=8080 node ./greeter.js
```

[参考](http://www.ruanyifeng.com/blog/2017/05/websocket.html)