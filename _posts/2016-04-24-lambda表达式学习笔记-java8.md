>Lambda表达式(也称为闭包)是整个java 8 发行版本中最受期待的在java 语言层面上的改变，Lambda允许把函数作为一个方法的参数(函数作为参数传递进方法中)，或者把代码看成数据：函数式程序员对这一概念非常熟悉。在此之前，java程序员使用匿名类来代替Lambda.
在最简单的Lambda形式中，一个lambda可以由用逗号分隔的参数列表、->符号与函数体三部分表示。例如：

```java
Arrays.asList("a","b","c").forEach(e -> System.out.println(e));
```
>其中注意参数e的类型是由编译器推测出来的。同时，你也可以通过把参数类型与参数包括在括号中的形式直接给出参数类型。某些情况下lambda的函数体会更加复杂，这时可以把函数体放到一对花括号中，就像在java中定义普通函数一样

1. lambda可以引用类的成员变量与局部变量(`如果这些变量不是final的话,他们会被隐含的转为final，这样效率更高`).例如下面两个片段是等价的：
```java
String separator = ",";
Arrays.asList("a","b","d").forEach(
	e -> System.out.print(e + separator);
);
//上面片段等价于下面片段
final String separator = ",";
Arrays.asList("a","b","d").forEach(
	e -> System.out.print(e + separator);
);
```

2. lambda可能会返回一个值。返回值的类型也是编译器推测出来的。
3. 函数式接口：函数式接口就是一个具有一个方法的普通接口。像这样的接口，可以被隐式的转换为lambda表达式。java 8增加了一种特殊的注解`@Functionallterface`。其中默认方法和静态方法并不影响函数式接口的契约