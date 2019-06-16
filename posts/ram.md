### 内存性能评估

利用free指令监控内存, free是监控linux内存使用状态最常用的指令

```shell
free -m -s 2 -c 5
             total       used       free     shared    buffers     cached
Mem:          7455       6956        498          0       1403       4569
-/+ buffers/cache:        984       6471
Swap:            0          0          0

             total       used       free     shared    buffers     cached
Mem:          7455       6957        498          0       1403       4569
-/+ buffers/cache:        984       6471
Swap:            0          0          0

             total       used       free     shared    buffers     cached
Mem:          7455       6957        498          0       1403       4569
-/+ buffers/cache:        984       6470
Swap:            0          0          0

             total       used       free     shared    buffers     cached
Mem:          7455       6957        498          0       1403       4569
-/+ buffers/cache:        984       6471
Swap:            0          0          0

             total       used       free     shared    buffers     cached
Mem:          7455       6957        498          0       1403       4569
-/+ buffers/cache:        984       6470
Swap:            0          0          0
```



mem: 表示物理内存统计

​	total: 表示物理内存总量

​	used: 表示总计分配给缓存(buffers与cache)使用的数量, 但其中可能部分缓存并未实际使用

​	free: 未被分配的内存

​	shared: 共享内存, 一般系统不会用到

​	buffers: 系统分配但未被使用的buffers数量

​	cached: 系统分配但未被使用的cache数量

-/+ buffers/cache: 表示物理内存的缓存统计

​	used: 第一行中的used-buffers-cached 也是实际使用的内存总量

​	free: 未被使用的buffers与cached和未被分配的内存之和, 这就是系统当前实际可用内存=free+buffes+cached

因为buffers和cached是系统为了提高性能申请的内存数, 实际上当应用程序需要此功能时, 是可以使用这些内存的, 所以对应用程序来说, 这些内存是可以使用的

swap: 表示硬盘上交换分区的使用情况

所以应用程序可用内存为: 1403 + 4569 +498=  6470  => 6470 / 7455 = 0.86787

**所以ft内存资源充足**

#### vmstat

* memory

  swpd列表示切换到内存交换区的内存数量(以k为单位). 如果swpd的值不为0, 或者比较大, 只要si,so长期为0, 这种情况下一般不用担心, 不会影响系统性能

  free列表表示单枪空闲的物理内存数量

  buff列表示buffers cache的内存数量, 一般对块设备的读写才需要缓冲

  cache列表示page cached的内存量, 一般作为文件系统的cached, 频繁访问的文件都为被cached, 如果cache值较大, 说明cached的文件数较多, 如果IO中bi比较小, 说明文件系统的效率比较好

* swap 

  si列表示由磁盘调入内存, 也就是内存进入内存交换区的数量.

  so列表示内存调入磁盘, 也就是内存交换区进入内存的数量

  一般情况下, si, so的值都为0, 如果si,so的值长期不为0, 则表示系统内存不足,需要增加系统内存