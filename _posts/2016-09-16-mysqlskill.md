---
layout: post
title: mysql学习和一些小技巧
categories: mysql

---



* join 默认为inner join,其只显示公共部分的数据，可以用下图表示  
  ![](http://www.habadog.com.img.800cdn.com/wp-content/uploads/2013/06/inner_join.jpg)  
* left join 和right join差不多，两者可以相互转换，显示其中某一张表的所有数据，另一张表如果没有对应的数据则用null填充，如下图所示  
  ![](http://www.habadog.com.img.800cdn.com/wp-content/uploads/2013/06/left_join.jpg)  
* 如果在insert 语句末尾制订了 ON DUPLICATE KEY UPDATE,并且插入行后会导致在一个UNIQUE索引或PRIMARY KEY中出现重复值，则在出现重复值的时候执行UPDATE,如果不会导致唯一值列表重复的问题，则插入新行。官网示例如下：


```sql
INSERT INTO table (a,b,c) VALUES (1,2,3)
  ON DUPLICATE KEY UPDATE c=c+1;
UPDATE table SET c=c+1 WHERE a=1;
```


其他使用语法参见[链接](http://dev.mysql.com/doc/refman/5.0/en/insert-on-duplicate.html)  

* replace into 跟insert功能类似 ，不同点在于:replace into 首先尝试插入数据列表中，如果发现列表中已经有此行数据(根据主键或者唯一索引判断)则先删除慈航数据，然后插入新的数据，否则直接插入新的数据


```sql
replace into tb_name(col_name,...) values(...);
replace into tb_name(col_name,...) select ...
replace into tb_name set col_name = value,...
```


* **INSERT IGNORE 与INSERT INTO	的区别**

  > INSERT IGNORE与INSERT INTO的区别就是INSERT IGNORE会忽略数据库中已经存在的数据, 如果数据库没有数据, 就插入新的数据, 如果有数据的话就跳过这条数据. 这样就可以保留数据库中已经存在的数据, 达到在间隙中插入数据的目的



```sql
INSERT IGNORE INTO table_name (name) select name from table2
```



* 在开发中经常会遇到需要表复制的情况。


```sql
/**
 要求目标表table2必须存在，由于目标表table2已经存在，所以我们除了插入原表table1的字段外，还可以插入常量
*/
insert into table2 (field1,field2,...) select value1,value2,...from table1
/**
要求目标表table2不存在，因为插入时会自动创建表table2，并将table1中的指定的字段数据复制 到table2中
*/
select value1,value2,... into table2 from table1
```


* mysql 中update 的limit需要注意使用，其详细信息可参考手册

[MySQL Reference Manual](http://man.chinaunix.net/database/mysql/zh-4.1.0/06-4.html)
