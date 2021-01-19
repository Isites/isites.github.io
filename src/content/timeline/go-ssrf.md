---
title: "Go中的SSRF攻防战"
date: 2021-01-19T20:30:38+08:00
draft: true
toc: true
images:
tags:
  - Go
  - 网络篇
---

### 写在最前面
“年年岁岁花相似，岁岁年年人不同”，没有什么是永恒的，很多东西都将成为过去式。比如，我以前在文章中自称“笔者”，细细想来这个称呼还是有一定的距离感，经过一番深思熟虑后，我打算将文章中的自称改为“老许”。

关于自称，老许就不扯太远了，下面还是回到本篇的主旨。

### 什么是SSRF

SSRF英文全拼为`Server Side Request Forgery`，翻译为服务端请求伪造。攻击者在未能取得服务器权限时，利用服务器漏洞以服务器的身份发送一条构造好的请求给服务器所在内网。关于内网资源的访问控制，想必大家心里都有数。

![](https://note.youdao.com/yws/api/personal/file/WEB5e3f093a7664785b0c96e4d4a4fdd095?method=download&shareKey=30bddd4078d8dbe0f8bd62c34814ad94)

上面这个说法如果不好懂，那老许就直接举一个实际例子。现在很多写作平台都支持通过URL的方式上传图片，如果服务器对URL校验不严格，此时就为恶意攻击者提供了访问内网资源的可能。

“千里之堤，溃于蚁穴”，任何可能造成风险的漏洞我们程序员都不应忽视，而且这类漏洞很有可能会成为别人绩效的垫脚石。为了不成为垫脚石，下面老许就和各位读者一起看一下SSRF的攻防回合。

### 回合一：千变万化的内网地址

为什么用“千变万化”这个词？老许先不回答，请各位读者耐心往下看。下面，老许用`182.61.200.7`（www.baidu.com的一个IP地址）这个IP和各位读者一起复习一下IPv4的不同表示方式。

| 格式            | 值                 | 描述                                     |
| :-------------- | :----------------- | :--------------------------------------- |
| 点分十进制      | 182.61.200.7       | 常规表现方式                             |
| 点分八进制      | 0266.075.0310.07   | 每个字节被单独转换为八进制               |
| 点分十六进制    | 0xb6.0x3d.0xc8.0x7 | 每个字节被单独转换为十六进制             |
| 十进制          | 3057502215         | 用十进制写出的32位整数                   |
| 八进制          | 026617344007       | 用八进制写出32位整数                     |
| 十六进制        | 0xb63dc807         | 用十六进制写出32位整数                   |
| 点分混合制（4） | 182.0x3d.0310.7等  | 点分格式中，每个字节都可用任意的进制表达 |
| 点分混合制（3） | 182.0x3d.0144007等 | 将后面16位用八进制表示                   |
| 点分混合制（2） | 182.4048903等      | 将后面24为用10进制表示                   |

**注意⚠️**：点分混合制中，以点分割地每一部分均可以写作不同的进制（仅限于十、八和十六进制）。

上面仅是IPv4的不同表现方式，IPv6的地址也有三种不同表示方式。而这三种表现方式又可以有不同的写法。下面以IPv6中的回环地址`0:0:0:0:0:0:0:1`为例。
| 格式               | 值                  | 描述                                                         |
| :----------------- | :------------------ | :----------------------------------------------------------- |
| 冒分十六进制表示法 | 0:0:0:0:0:0:0:1     | 格式为X:X:X:X:X:X:X:X，其中每个X表示地址中的16b，每个X的前导0是可以省略 |
| 0位压缩表示法      | ::1                 | 连续的一段0可以压缩为“::”，但”::”只能出现一次                |
| 内嵌IPv4地址表示法 | 0:0:0:0:0:0:0.0.0.1 | X:X:X:X:X:X:d.d.d.d（前96b使用冒分十六进制，最后32b地址则使用IPv4的点分十进制表示） |

**注意⚠️**：冒分十六进制表示法中每个X的前导0是可以省略的，那么我可以部分省略，部分不省略，从而将一个IPv6地址写出不同的表现形式。0位压缩表示法和内嵌IPv4地址表示法同理也可以将一个IPv6地址写出不同的表现形式。

讲了这么多，老许已经无法统计一个IP可以有多少种不同的写法，麻烦数学好的算一下。

内网IP你以为到这儿就完了嘛？当然不！不知道各位读者有没有听过`xip.io`这个域名。`xip`可以帮你做自定义的DNS解析，并且可以解析到任意IP地址（包括内网）。

![](https://note.youdao.com/yws/api/personal/file/WEB85b07b5da343c8b1be8be6bdd19869f5?method=download&shareKey=a3ffcab0e1c03fbfa6383c5d736f3ea4)

我们通过`xip`提供的域名解析，还可以将内网IP通过域名的方式进行访问。

关于内网IP的访问到这儿仍将继续！搞过Basic验证的应该都知道，可以通过`http://user:passwd@hostname/`进行资源访问。如果攻击者换一种写法或许可以绕过部分不够严谨的逻辑，如下所示。

![](https://note.youdao.com/yws/api/personal/file/WEBac6328b4d92be511501ea6d4d2a7042d?method=download&shareKey=86a8308849c419d602d621b2bab1c93d)

关于内网地址，老许掏空了所有的知识储备总结出上述内容，因此老许说一句千变万化的内网地址不过分吧！

此时此刻，老许只想问一句，当恶意攻击者用这些不同表现形式的内网地址进行图片上传时，你怎么将其识别出来并拒绝访问。不会真的有大佬用正则表达式完成上述过滤吧，如果有请留言告诉我让小弟学习一下。

花样百出的内网地址我们已经基本了解，那么现在的问题是怎么将其转为一个我们可以进行判断的IP。总结上面的内网地址可分为三类：一、本身就是IP地址，仅表现形式不统一；二、一个指向内网IP的域名；三、一个包含Basic验证信息和内网IP的地址。根据这三类特征，在发起请求之前按照如下步骤可以识别内网地址并拒绝访问。

1. 解析出地址中的HostName。
2. 发起DNS解析，获得IP。
3. 判断IP是否是内网地址。

上述步骤中关于内网地址的判断，请不要忽略IPv6的回环地址和IPv6的唯一本地地址。下面是老许判断IP是否为内网IP的逻辑。

```go
// IsLocalIP 判断是否是内网ip
func IsLocalIP(ip net.IP) bool {
	if ip == nil {
		return false
	}
	// 判断是否是回环地址, ipv4时是127.0.0.1；ipv6时是::1
	if ip.IsLoopback() {
		return true
	}
	// 判断ipv4是否是内网
	if ip4 := ip.To4(); ip4 != nil {
		return ip4[0] == 10 || // 10.0.0.0/8
			(ip4[0] == 172 && ip4[1] >= 16 && ip4[1] <= 31) || // 172.16.0.0/12
			(ip4[0] == 192 && ip4[1] == 168) // 192.168.0.0/16
	}
	// 判断ipv6是否是内网
	if ip16 := ip.To16(); ip16 != nil {
		// 参考 https://tools.ietf.org/html/rfc4193#section-3
		// 参考 https://en.wikipedia.org/wiki/Private_network#Private_IPv6_addresses
		// 判断ipv6唯一本地地址
		return 0xfd == ip16[0]
	}
	// 不是ip直接返回false
	return false
}

```
下图为按照上述步骤检测请求是否是内网请求的结果。

![](https://note.youdao.com/yws/api/personal/file/WEB733788caa1f3e7307a0eb6eaf237db5e?method=download&shareKey=5df8b437bde3f8a6b40eb03f66e15d57)

**小结**：URL形式多样，可以使用DNS解析获取规范的IP，从而判断是否是内网资源。

### 回合二：URL跳转

如果恶意攻击者仅通过IP的不同写法进行攻击，那我们自然可以高枕无忧，然而这场矛与盾的较量才刚刚开局。

我们回顾一下回合一的防御策略，检测请求是否是内网资源是在正式发起请求之前，如果攻击者在请求过程中通过URL跳转进行内网资源访问则完全可以绕过回合一中的防御策略。具体攻击流程如下。

![](https://note.youdao.com/yws/api/personal/file/WEBe9de4e2a016b1d1f9b0d2dfa09ba7811?method=download&shareKey=65a87ed928726fc6c7fc34d362b1824d)

如图所示，通过URL跳转攻击者可获得内网资源。在介绍如何防御URL跳转攻击之前，老许和各位读者先一起复习一下HTTP重定向状态码——3xx。

根据维基百科的资料，3xx重定向码范围从300到308共9个。老许特意瞧了一眼go的源码，发现官方的`http.Client`发出的请求仅支持如下几个重定向码。

`301`：请求的资源已永久移动到新位置；该响应可缓存；重定向请求一定是GET请求。

`302`：要求客户端执行临时重定向；只有在Cache-Control或Expires中进行指定的情况下，这个响应才是可缓存的；重定向请求一定是GET请求。

`303`：当POST（或PUT / DELETE）请求的响应在另一个URI能被找到时可用此code，这个code存在主要是为了允许由脚本激活的POST请求输出重定向到一个新的资源；303响应禁止被缓存；重定向请求一定是GET请求。

`307`：临时重定向；不可更改请求方法，如果原请求是POST，则重定向请求也是POST。

`308`：永久重定向；不可更改请求方法，如果原请求是POST，则重定向请求也是POST。

3xx状态码复习就到这里，我们继续SSRF的攻防回合讨论。既然服务端的URL跳转可能带来风险，那我们只要禁用URL跳转就完全可以规避此类风险。然而我们并不能这么做，这个做法在规避风险的同时也极有可能误伤正常的请求。那到底该如何防范此类攻击手段呢？

看过老许“[Go中的HTTP请求之——HTTP1.1请求流程分析](https://mp.weixin.qq.com/s/6WYhwaRrjv6W6NZCNw2CeA)”这篇文章的读者应该知道，对于重定向有业务需求时，可以自定义http.Client的`CheckRedirect`。下面我们先看一下`CheckRedirect`的定义。
```go
CheckRedirect func(req *Request, via []*Request) error
```
这里特别说明一下，`req`是即将发出的请求且请求中包含前一次请求的响应，`via`是已经发出的请求。在知晓这些条件后，防御URL跳转攻击就变得十分容易了。

1. 根据前一次请求的响应直接拒绝`307`和`308`的跳转（此类跳转可以是POST请求，风险极高）。
2. 解析出请求的IP，并判断是否是内网IP。

根据上述步骤，可如下定义`http.Client`。
```go
client := &http.Client{
	CheckRedirect: func(req *http.Request, via []*http.Request) error {
		// 跳转超过10次，也拒绝继续跳转
		if len(via) >= 10 {
			return fmt.Errorf("redirect too much")
		}
		statusCode := req.Response.StatusCode
		if statusCode == 307 || statusCode == 308 {
			// 拒绝跳转访问
			return fmt.Errorf("unsupport redirect method")
		}
		// 判断ip
		ips, err := net.LookupIP(req.URL.Host)
		if err != nil {
			return err
		}
		for _, ip := range ips {
			if IsLocalIP(ip) {
				return fmt.Errorf("have local ip")
			}
			fmt.Printf("%s -> %s is localip?: %v\n", req.URL, ip.String(), IsLocalIP(ip))
		}
		return nil
	},
}
```

如上自定义CheckRedirect可以防范URL跳转攻击，但此方式会进行多次DNS解析，效率不佳。后文会结合其他攻击方式介绍更加有效率的防御措施。

**小结**：通过自定义`http.Client`的`CheckRedirect`可以防范URL跳转攻击。

### 回合三：DNS Rebinding

众所周知，发起一次HTTP请求需要先请求DNS服务获取域名对应的IP地址。如果攻击者有可控的DNS服务，就可以通过DNS重绑定绕过前面的防御策略进行攻击。

具体流程如下图所示。

![](https://note.youdao.com/yws/api/personal/file/WEBa90ecbaeb18110063a5e91d1704f4c8a?method=download&shareKey=fc64d48577f5e66e69ea10616cd28344)

验证资源是是否合法时，服务器进行了第一次DNS解析，获得了一个非内网的IP且TTL为0。对解析的IP进行判断，发现非内网IP可以后续请求。由于攻击者的DNS Server将TTL设置为0，所以正式发起请求时需要再次进行DNS解析。此时DNS Server返回内网地址，由于已经进入请求资源阶段再无防御措施，所以攻击者可获得内网资源。

> 额外提一嘴，老许特意看了Go中DNS解析的部分源码，发现Go并没有对DNS的结果作缓存，所以即使TTL不为0也存在DNS重绑定的风险。

在发起请求的过程中有DNS解析才让攻击者有机可乘。如果我们能对该过程进行控制，就可以避免DNS重绑定的风险。对HTTP请求控制可以通过自定义`http.Transport`来实现，而自定义`http.Transport`也有两个方案。

**方案一**：
```go
dialer := &net.Dialer{}
transport := http.DefaultTransport.(*http.Transport).Clone()
transport.DialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
	host, port, err := net.SplitHostPort(addr)
	// 解析host和 端口
	if err != nil {
		return nil, err
	}
	// dns解析域名
	ips, err := net.LookupIP(host)
	if err != nil {
		return nil, err
	}
	// 对所有的ip串行发起请求
	for _, ip := range ips {
		fmt.Printf("%v -> %v is localip?: %v\n", addr, ip.String(), IsLocalIP(ip))
		if IsLocalIP(ip) {
			continue
		}
		// 非内网IP可继续访问
		// 拼接地址
		addr := net.JoinHostPort(ip.String(), port)
		// 此时的addr仅包含IP和端口信息
		con, err := dialer.DialContext(ctx, network, addr)
		if err == nil {
			return con, nil
		}
		fmt.Println(err)
	}

	return nil, fmt.Errorf("connect failed")
}
// 使用此client请求，可避免DNS重绑定风险
client := &http.Client{
	Transport: transport,
}
```
`transport.DialContext`的作用是创建未加密的TCP连接，我们通过自定义此函数可规避DNS重绑定风险。另外特别说明一下，如果传递给`dialer.DialContext`方法的地址是常规IP格式则可使用net包中的`parseIPZone`函数直接解析成功，否则会继续发起DNS解析请求。

**方案二**：
```go
dialer := &net.Dialer{}
dialer.Control = func(network, address string, c syscall.RawConn) error {
    // address 已经是ip:port的格式
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return err
	}
	fmt.Printf("%v is localip?: %v\n", address, IsLocalIP(net.ParseIP(host)))
	return nil
}
transport := http.DefaultTransport.(*http.Transport).Clone()
// 使用官方库的实现创建TCP连接
transport.DialContext = dialer.DialContext
// 使用此client请求，可避免DNS重绑定风险
client := &http.Client{
	Transport: transport,
}
```

`dialer.Control`在创建网络连接之后实际拨号之前调用，且仅在go版本大于等于1.11时可用，其具体调用位置在`sock_posix.go`中的`(*netFD).dial`方法里。

![](https://note.youdao.com/yws/api/personal/file/WEB149c44c0f615142a792ed61dc8ef81d2?method=download&shareKey=a215bcf6853fe43b9a3d1f6b74a8fb3a)

上述两个防御方案不仅仅可以防范DNS重绑定攻击，也同样可以防范其他攻击方式。事实上，老许更加推荐方案二，简直一劳永逸！

**小结**：
1. 攻击者可以通过自己的DNS服务进行DNS重绑定攻击。
2. 通过自定义`http.Transport`可以防范DNS重绑定攻击。

### 个人经验

1、不要下发详细的错误信息！不要下发详细的错误信息！不要下发详细的错误信息！

如果是为了开发调试，请将错误信息打进日志文件里。强调这一点不仅仅是为了防范SSRF攻击，更是为了避免敏感信息泄漏。例如，DB操作失败后直接将error信息下发，而这个error信息很有可能包含SQL语句。

> 再额外多说一嘴，老许的公司对打进日志文件的某些信息还要求脱敏，可谓是十分严格了。

2、限制请求端口。

在结束之前特别说明一下，SSRF漏洞并不只针对HTTP协议。本篇只讨论HTTP协议是因为go中通过`http.Client`发起请求时会检测协议类型，某P*P语言这方面检测就会弱很多。虽然`http.Client`会检测协议类型，但是攻击者仍然可以通过漏洞不断更换端口进行内网端口探测。

最后，衷心希望本文能够对各位读者有一定的帮助。

> **注**：
>
> 1. 写本文时， 笔者所用go版本为: go1.15.2
> 2. 文章中所用完整例子：https://github.com/Isites/go-coder/blob/master/ssrf/main.go

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)