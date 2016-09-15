### Make的概念

---

Make这个词, 英语的意思是"制作". Make命令直接用了这个意思, 就是要做出某个文件. 比如, 要做出文件a.txt, 就可以执行下面的命令

```shell
make a.txt
#Makefile也可以携程makefile, 或者用命令行参数指定为其他文件名
make -f rules.txt
make --file=rules.txt
```

### Makefile文件的格式

---

makefile文件由一系列规则(rules)构成. 每条规则形式如下:

```markdown
<target> : <prerequisites>
[tab]	<commands>
```

上面第一行冒号前面部分, 叫做"目标"(target), 冒号后面的部分叫做"前置条件"(prerequisites); 第二行必须由一个tab键起首, 后面跟着"命令"(commands)

#### 目标

一个目标就构成一条规则. 目标通常是文件名, 指明Make命令要构建的对象.目标可以是一个文件名, 也可以是多个文件名, 之间用空格分隔.

除了文件名, 目标还可以是某个操作的名字, 这称为"伪目标"(phony target)

```shell
clean:
	rm *.o
#######################调用写好的makefile文件
make clean
```

如果当前目录中, 正好有一个文件叫做clean, 那么这个命令不会执行. 因为Make发现clean文件已经存在, 就认为没有必要重新构建了, 就不会执行指定的rm命令. 为了避免这种情况, 可以明确声明clean是"伪目标":

```shell
.PHONY clean
clean:
	rm *.o temp
```

声明clean为"伪目标"之后, make就不会去检查是否存在一个叫做clean的文件, 而是每次运行都执行对应的命令. 像`.PHONY`这样的内置目标名还有不少, 可以查看[手册](http://www.gnu.org/software/make/manual/html_node/Special-Targets.html#Special-Targets). 如果make命令运行时没有指定目标, 默认会执行Makefile文件的第一个目标.

#### 前置条件

前置条件通常是一组文件名, 之间用空格分隔. 它指定了"目标"是否重新构建的判断标准: 只要有一个前置文件不存在, 或者有过更新(前置文件的last-modification时间戳比目标的时间戳新), "目标"就需要重新构建.

#### 命令

命令(commands)表示如何更新目标文件, 有一行或多行的Shell命令组成. 他是构建"目标"的具体指令, 它的运行结果通常就是生成目标文件.

每行命令之前必须有一个tab键. 如果想用其他键, 可以用内置变量`.RECIPEPREFIX`声明	

```shell
.RECIPEPREFIX = >
all:
> echo hello, world
```

> 需要注意的是, 每行命令在一个单独的shell中执行. 这些shell之间没有继承关系

```shell
var-lost:
	export foo=bar
	echo "foo=[$$fool]"
```

上面代码执行(`make var-lost`), 取不到foo的值. 因为两个命令在不同的进程执行. 一个解决办法是将两行命令写在一行, 中间用分号分隔. 另一个解决办法是在换行符前加反斜杠转义. 最后一个方法是加上`.ONESHELL`命令

### Makefile文件的语法

#### 回声

正常情况下, make会打印每条命令, 然后再执行, 这就叫做回声(echoing).

**在命令前面加上@**, 就可以关闭回声



#### 变量和赋值

Makefile以供提供了四个赋值运算符(`=,:=,?=,+=`)

**=** 递归赋值, 即赋值后并不马上生效, 等到使用时才真正的赋值, 此时通过递归找出当前的值

**?=** 仅仅在变量还没赋值的情况下才生效, 所以一般用在第一次赋值

**:=** 直接赋值, 这就是我们常规的那种赋值方式, 一赋值马上生效. 在没赋值时 是空字符

**+=** 在变量后加上字符



[参考](http://www.ruanyifeng.com/blog/2015/02/make.html)

