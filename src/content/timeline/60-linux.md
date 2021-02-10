---
title: "1分钟内的Linux性能分析法"
date: 2021-02-01T20:30:38+08:00
draft: true
toc: true
images:
tags:
  - linux
---


> 本着“拿来主义”的精神，吸收他人长处为己用。老许翻译一篇Linux性能分析相关的文章分享给各位读者，同时也加深自己的印象。


你登录到具有性能问题的Linux服务器时，第一分钟要检查什么？

在Netflix，我们拥有庞大的Linux EC2云实例，以及大量的性能分析工具来监视和调查它们的性能。这些工具包括`Atlas`和`Vector`。`Atlas`用于全云监控，`Vector`用于按需实例分析。这些工具能帮助我们解决大部分问题，但有时候我们仍需登录实例并运行一些标准的Linux性能工具。

> Atlas：根据github上面的文档老许简单说一下自己的认知。一个可以管理基于时间维度数据的后端，同时具有内存存储功能可以非常快速地收集和报告大量指标。
>
> Vector：Vector是一个主机上的性能监视框架，它可以将各种指标展示在工程师的浏览器上面。

### 总结

在这篇文章中，Netflix性能工程团队将向您展示通过命令行进行性能分析是，前60秒应该使用那些Linux标准工具。在60秒内，你可以通过以下10个命令来全面了解系统资源使用情况和正在运行的进程。首先寻找错误和饱和指标，因为他们很容易理解，然后是资源利用率。饱和是指资源负载超出其处理能力，其可以表现为一个请求队列的长度或者等待时间。

```bash
uptime
dmesg | tail
vmstat 1
mpstat -P ALL 1
pidstat 1
iostat -xz 1
free -m
sar -n DEV 1
sar -n TCP,ETCP 1
top
```

其中一些命令需要安装sysstat软件包。这些命令暴露的指标是一种帮助你完成`USE Method（Utilization Saturation and Errors Method）`——一种查找性能瓶颈的方法。这涉及检查所有资源（CPU、内存、磁盘等）利用率，饱和度和错误等指标。同时还需注意通过排除法可以逐步缩小资源检查范围。

以下各节通过生产系统中的示例总结了这些命令。这些命令的更多信息，请参考使用手册。

### uptime

```bash
$ uptime 
23:51:26 up 21:31, 1 user, load average: 30.02, 26.43, 19.02
```
这是一种快速查看平均负载的方法，它指示了等待运行的进程数量。在Linux系统上，这些数字包括要在CPU上运行的进程以及处于I/O（通常是磁盘I/O）阻塞的进程。这提供了资源负载的大概状态，没有其他工具就无法理解更多。仅值得一看。

这三个数字分别代表着1分钟、5分钟和15分钟内的平均负载。这三个指标让我们了解负载是如何随时间变化的。例如，你被要求检查有问题的服务器，而1分钟的值远低于15分钟的值，则意味着你可能登录的太晚而错过了问题现场。

在上面的例子中，最近的平均负载增加，一分钟值达到30，而15分钟值达到19。数字如此之大意味着很多：可能是CPU需求（可以通过后文中介绍的vmstat或mpstat命令来确认）。

### dmesg | tail

```bash
$ dmesg | tail
[1880957.563150] perl invoked oom-killer: gfp_mask=0x280da, order=0, oom_score_adj=0
[...]
[1880957.563400] Out of memory: Kill process 18694 (perl) score 246 or sacrifice child
[1880957.563408] Killed process 18694 (perl) total-vm:1972392kB, anon-rss:1953348kB, file-rss:0kB
[2320864.954447] TCP: Possible SYN flooding on port 7001. Dropping request.  Check SNMP counters.
```
如果有消息，它将查看最近的10条系统消息。通过此命令查找可能导致性能问题的错误。上面的示例包括`oom-killer`和TCP丢弃请求。

不要错过这一步！`dmesg`始终值得被检查。

### vmstat 1

```bash
$ vmstat 1
procs ---------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
34  0    0 200889792  73708 591828    0    0     0     5    6   10 96  1  3  0  0
32  0    0 200889920  73708 591860    0    0     0   592 13284 4282 98  1  1  0  0
32  0    0 200890112  73708 591860    0    0     0     0 9501 2154 99  1  0  0  0
32  0    0 200889568  73712 591856    0    0     0    48 11900 2459 99  0  0  0  0
32  0    0 200890208  73712 591860    0    0     0     0 15898 4840 98  1  1  0  0
^C
```

vmstat是虚拟内存状态的缩写。它在每一行上打印关键服务的统计信息。

vmstat在参数1下运行，以显示一秒钟的摘要。在某些版本中，第一行的某些列展示的是自启动以来的平均值，而不是前一秒的平均值。现在请跳过第一行，除非你想学习并记住那一列是那一列。

要检查的列：

* **r**：在CPU上运行并等待切换的进程数。这为确定CPU饱和比平均负载提供了更好的信号，因为它不包括I/O。简单来说就是：r的值大于CPU数量即为饱和状态。
* **free**：可用内存以字节为单位，如果数字很大，则说明你有足够的可用内存。`free -m`命令能够更好的描述此状态。
* **si, so**：swap-ins和swap-outs. 如果这两个值不为0，则说明内存不足。
* **us, sy, id, wa, st**：这是总CPU时间的百分比。他们分别是用户时间、系统时间（内核）、空闲时间（包括I/O等待）、I/O等待和被盗时间（虚拟机所消耗的时间）。

![](https://note.youdao.com/yws/api/personal/file/WEB01cdb925877dcd06f2f969101decea65?method=download&shareKey=5388ed636ef3cecb60d096cff7ad6615)

> 最后关于us, sy, id, wa, st的解释和原文不太一样，所以老许贴一下vmstat手册中的解释。

通过用户时间+系统时间来确认CPU是否繁忙。如果有持续的等待I/O，意味着磁盘瓶颈。这是CPU空闲的时候，因为任务等待I/O被阻塞。你可以将I/O等待视为CPU空闲的另一种形式，同时它也提供了CPU为什么空闲的线索。

I/O处理需要消耗系统时间。一个系统时间占比较高（比如超过20%）值得进一步研究，可能是内核处理I/O的效率低下。

在上面的例子中，CPU时间几乎完全处于用户级别，即CPU时间几乎被应用程序占用。CPU平均利用率也超过90%，这不一定是问题，还需要通过r列的值检查饱和度。

### mpstat -P ALL 1

```bash
$ mpstat -P ALL 1
Linux 3.13.0-49-generic (titanclusters-xxxxx)  07/14/2015  _x86_64_ (32 CPU)

07:38:49 PM  CPU   %usr  %nice   %sys %iowait   %irq  %soft  %steal  %guest  %gnice  %idle
07:38:50 PM  all  98.47   0.00   0.75    0.00   0.00   0.00    0.00    0.00    0.00   0.78
07:38:50 PM    0  96.04   0.00   2.97    0.00   0.00   0.00    0.00    0.00    0.00   0.99
07:38:50 PM    1  97.00   0.00   1.00    0.00   0.00   0.00    0.00    0.00    0.00   2.00
07:38:50 PM    2  98.00   0.00   1.00    0.00   0.00   0.00    0.00    0.00    0.00   1.00
07:38:50 PM    3  96.97   0.00   0.00    0.00   0.00   0.00    0.00    0.00    0.00   3.03
[...]
```

此命令用于显示每个CPU的CPU时间明细，可用于检查不平衡的情况。单个热CPU可能是因为存在一个单线程应用。

### pidstat 1

```bash
$ pidstat 1
Linux 3.13.0-49-generic (titanclusters-xxxxx)  07/14/2015    _x86_64_    (32 CPU)

07:41:02 PM   UID       PID    %usr %system  %guest    %CPU   CPU  Command
07:41:03 PM     0         9    0.00    0.94    0.00    0.94     1  rcuos/0
07:41:03 PM     0      4214    5.66    5.66    0.00   11.32    15  mesos-slave
07:41:03 PM     0      4354    0.94    0.94    0.00    1.89     8  java
07:41:03 PM     0      6521 1596.23    1.89    0.00 1598.11    27  java
07:41:03 PM     0      6564 1571.70    7.55    0.00 1579.25    28  java
07:41:03 PM 60004     60154    0.94    4.72    0.00    5.66     9  pidstat

07:41:03 PM   UID       PID    %usr %system  %guest    %CPU   CPU  Command
07:41:04 PM     0      4214    6.00    2.00    0.00    8.00    15  mesos-slave
07:41:04 PM     0      6521 1590.00    1.00    0.00 1591.00    27  java
07:41:04 PM     0      6564 1573.00   10.00    0.00 1583.00    28  java
07:41:04 PM   108      6718    1.00    0.00    0.00    1.00     0  snmp-pass
07:41:04 PM 60004     60154    1.00    4.00    0.00    5.00     9  pidstat
^C
```

`pidstat`有点像top的每个进程摘要，但是会打印滚动摘要，而不是清除屏幕。这对于观察随时间变化的模式很有用，还可以将看到的内容记录下来。

上面的示例中，两个java进程消耗了大部分CPU时间。%CPU这一列是所有CPU的总和。`1591%`意味着java进程几乎耗尽了16个CPU。


### iostat -xz 1

```bash
$ iostat -xz 1
Linux 3.13.0-49-generic (titanclusters-xxxxx)  07/14/2015  _x86_64_ (32 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
          73.96    0.00    3.73    0.03    0.06   22.21

Device:   rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
xvda        0.00     0.23    0.21    0.18     4.52     2.08    34.37     0.00    9.98   13.80    5.42   2.44   0.09
xvdb        0.01     0.00    1.02    8.94   127.97   598.53   145.79     0.00    0.43    1.78    0.28   0.25   0.25
xvdc        0.01     0.00    1.02    8.86   127.79   595.94   146.50     0.00    0.45    1.82    0.30   0.27   0.26
dm-0        0.00     0.00    0.69    2.32    10.47    31.69    28.01     0.01    3.23    0.71    3.98   0.13   0.04
dm-1        0.00     0.00    0.00    0.94     0.01     3.78     8.00     0.33  345.84    0.04  346.81   0.01   0.00
dm-2        0.00     0.00    0.09    0.07     1.35     0.36    22.50     0.00    2.55    0.23    5.62   1.78   0.03
[...]
^C
```
这是一个非常好的工具，不仅可以了解块设备（磁盘）的工作负载还可以了解其性能。

* **r/s, w/s, rkB/s, wkB/s**：分别表示每秒交付给设备的读写请求数和每秒读写的KB数。这些可以描述设备的工作负载。性能问题可能仅仅是由于施加了过多的负载。
* **await**：I/O处理时间（毫秒为单位），这包括队列中请求所花费的时间以及为请求服务所花费的时间。如果值大于预期的平均时间，可能是因为设备已经饱和或设备出现问题。
* **avgqu-sz**：发送给设备请求的平均队列长度。该值大于1表明设备已达饱和状态（尽管设备通常可以并行处理请求，尤其是有多个后端磁盘的虚拟设备）。
* **%util**：设备利用率。这是一个显示设备是否忙碌的百分比，其含义为设备每秒的工作时间占比。该值大于60%时通常会导致性能不佳（可以在await中看出来），不过它也和具体的设备有关。值接近100%时，意味着设备已饱和。

![](https://note.youdao.com/yws/api/personal/file/WEBd50303583de5aa29ab979335165035d3?method=download&shareKey=12535f772898d9ce28dd23ebcc104686)

> 关于avgqu-sz的解释和原文不太一样，所以老许贴一下iostat手册中的解释。

如果存储设备是位于很多磁盘前面的逻辑磁盘设备，则100%利用率可能仅仅意味着所有时间都在处理I/O，但是后端磁盘可能远远还没有饱和，而且还能处理更多的工作。

请记住，磁盘I/O性能不佳不一定是应用程序的问题。通常使用许多技术来异步执行I/O，以保证应用程序不被阻塞或直接遭受延迟（例如，预读用于读取，缓冲用于写入）。

### free -m

```bash
$ free -m
             total       used       free     shared    buffers     cached
Mem:        245998      24545     221453         83         59        541
-/+ buffers/cache:      23944     222053
Swap:            0          0          0
```
看最右边两列：

* **buffers**：缓冲区缓存，用于块设备I/O。
* **cached**：页缓存，用于文件系统。

我们检查他们的值是否接近0，接近0会导致更高的磁盘I/O（可以通过iostat来确认）以及更糟糕的磁盘性能。上面的示例看起来不错，每个值都有许多兆字节。

`-/+ buffers/cache`为已用内存和可用内存提供更加清晰的描述。Linux将部分空闲内存用作缓存，但是在应用程序需要时可以快速回收。因此，用作缓存的内存应该应该以某种方式包含在free这一列，`-/+ buffers/cache`这一行就是做这个事情的。

> 上面这一段翻译，可能比较抽象，感觉说的不像人话，老许来转述成人能理解的话：
>
> total = used + free
>
> used = (-/+ buffers/cache这一行used对应列) + buffers + cached
>
> => 24545 = 23944 + 59 + 541
> 
> free = (-/+ buffers/cache这一行free对应列) - buffers - cached
>
>=> 221453 = 222053 - 59 - 541

如果在Linux使用了ZFS会令人更加疑惑（就像我们对某些服务所做的一样），因为ZFS有自己的文件系统缓存。而`free -m`并不能正确反应该文件系统缓存。它可能表现为，系统可用内存不足，而实际上该内存可根据需要从ZFS缓存中使用。

> ZFS: Zettabyte File System,也叫动态文件系统，更多信息见百度百科

### sar -n DEV 1

```bash
$ sar -n DEV 1
Linux 3.13.0-49-generic (titanclusters-xxxxx)  07/14/2015     _x86_64_    (32 CPU)

12:16:48 AM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
12:16:49 AM      eth0  18763.00   5032.00  20686.42    478.30      0.00      0.00      0.00      0.00
12:16:49 AM        lo     14.00     14.00      1.36      1.36      0.00      0.00      0.00      0.00
12:16:49 AM   docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00

12:16:49 AM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
12:16:50 AM      eth0  19763.00   5101.00  21999.10    482.56      0.00      0.00      0.00      0.00
12:16:50 AM        lo     20.00     20.00      3.25      3.25      0.00      0.00      0.00      0.00
12:16:50 AM   docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
^C
```

可以用这个工具检查网络接口的吞吐量： rxkB/s和txkB/s。作为工作负载的度量，还可以检查吞吐量是否达到上限。在上面的列子中，eth0的接受速度达到22Mbyte/s（176Mbit/s），该值远低于1Gbit/s的限制。

> 原文中无rxkB/s和txkB/s的解释，老许特意找了使用手册中的说明。

![](https://note.youdao.com/yws/api/personal/file/WEBc64cc99088cee47bede3119305116a7c?method=download&shareKey=238ac957dd1380595eb90706cfb9c157)

这个版本还有%ifutil作设备利用率，这也是我们使用Brendan的nicstat工具来测量的。和nicstat工具一样，这很难正确，而且本例中看起来该值并不起作用。

> 老许试了一下自己的云服务发现%ifutil指标并不一定都有。

![](https://note.youdao.com/yws/api/personal/file/WEB46426284a4f97e9d965dc6c74b3045c0?method=download&shareKey=341078089ef7ed5608f35d1bef2f516a)

### sar -n TCP,ETCP 1

```bash
$ sar -n TCP,ETCP 1
Linux 3.13.0-49-generic (titanclusters-xxxxx)  07/14/2015    _x86_64_    (32 CPU)

12:17:19 AM  active/s passive/s    iseg/s    oseg/s
12:17:20 AM      1.00      0.00  10233.00  18846.00

12:17:19 AM  atmptf/s  estres/s retrans/s isegerr/s   orsts/s
12:17:20 AM      0.00      0.00      0.00      0.00      0.00

12:17:20 AM  active/s passive/s    iseg/s    oseg/s
12:17:21 AM      1.00      0.00   8359.00   6039.00

12:17:20 AM  atmptf/s  estres/s retrans/s isegerr/s   orsts/s
12:17:21 AM      0.00      0.00      0.00      0.00      0.00
^C
```

这是一些关键TCP指标的总结。其中包括：

* **active/s**：本地每秒启动的TCP连接数（例如，通过connect()）。
* **passive/s**：远程每秒启动的TCP连接数（例如，通过accept()）
* **retrans/s**：TCP每秒重传次数。

active和passive连接数通常用于服务器负载的粗略度量。将active视为向外的连接，passive视为向内的连接可能会有帮助，但这样区分并不严格（例如，localhost连接到localhost）。

重传是网络或服务器出问题的迹象。它可能是不可靠的网络（例如，公共Internet），也可能是由于服务器过载并丢弃了数据包。上面的示例显示每秒仅一个新的TCP连接。

### top

```bash
$ top
top - 00:15:40 up 21:56,  1 user,  load average: 31.09, 29.87, 29.92
Tasks: 871 total,   1 running, 868 sleeping,   0 stopped,   2 zombie
%Cpu(s): 96.8 us,  0.4 sy,  0.0 ni,  2.7 id,  0.1 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem:  25190241+total, 24921688 used, 22698073+free,    60448 buffers
KiB Swap:        0 total,        0 used,        0 free.   554208 cached Mem

   PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
 20248 root      20   0  0.227t 0.012t  18748 S  3090  5.2  29812:58 java
  4213 root      20   0 2722544  64640  44232 S  23.5  0.0 233:35.37 mesos-slave
 66128 titancl+  20   0   24344   2332   1172 R   1.0  0.0   0:00.07 top
  5235 root      20   0 38.227g 547004  49996 S   0.7  0.2   2:02.74 java
  4299 root      20   0 20.015g 2.682g  16836 S   0.3  1.1  33:14.42 java
     1 root      20   0   33620   2920   1496 S   0.0  0.0   0:03.82 init
     2 root      20   0       0      0      0 S   0.0  0.0   0:00.02 kthreadd
     3 root      20   0       0      0      0 S   0.0  0.0   0:05.35 ksoftirqd/0
     5 root       0 -20       0      0      0 S   0.0  0.0   0:00.00 kworker/0:0H
     6 root      20   0       0      0      0 S   0.0  0.0   0:06.94 kworker/u256:0
     8 root      20   0       0      0      0 S   0.0  0.0   2:38.05 rcu_sched
```


top命令包含我们之前检查的许多指标。运行它可以很方便地查看是否有任何东西和之前的命令结果差别很大。

top的缺点是随着时间推移不能看到相关变化，像vmstat和pidstat之类提供滚动输出的工具则能体现的更加清楚。如果你没有足够快地暂停输出（Ctrl-S暂停, Ctrl-Q继续），随着屏幕的清除间歇性问题的证据很有可能丢失。

最后，衷心希望本文能够对各位读者有一定的帮助。

翻译原文

https://netflixtechblog.com/linux-performance-analysis-in-60-000-milliseconds-accc10403c55

【关注公众号】

![](https://note.youdao.com/yws/api/personal/file/WEBa3ee67b2b867e98cb5c587f4adfa6801?method=download&shareKey=0fbb95d0aec6170b854e7b890d50d559)