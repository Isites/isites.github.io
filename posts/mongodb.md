### 集合

集合是一组mongodb的文件.它与一个RDBMS表是等效的. 一个集合存在于数据库中. 集合不强制执行模式, 集合中的文档可以有不同的字段. 通常情况下, 在一个集合中的所有文件都是类似或相关目的

### 文档

文档是一组键值对. 文档具有动态模式, 动态模式是指, 在同一个集合的文件不必具有相同一组集合的文档字段或结构, 并且相同的字段可以保持不同类型的数据.

### 语法

#### 创建数据库

Mongodb 用`use database`创建数据库. 该命令如果数据库不存在, 将创建一个新的数据库, 否则将返回现有的数据库.

```sql
-- 检查当前选择的数据库
> db
-- 如果想查询数据库列表
> show dbs
```

所创建的数据库, 不存在于列表中, 要显示数据库, 需要至少插入一个文档进去. Mongodb的默认数据库是test, 如果没有创建任何数据库, 那么集合将被保存在测试数据库

#### 删除数据库

```sql
-- 删除现有的数据库, 如果没有选择任何数据库, 那么它将删除默认的'test'数据库
> db.dropDatabase()
-- 删除mymongo db
> use mymongo
> db.dropDatabase()
```

#### 创建集合

Mongodb 的`db.createCollection(name, options)` 用于创建结合. name: 是要创建集合的名称. Options是一个文档, 用于指定集合的配置

| 参数      | 类型       | 描述                 |
| ------- | -------- | ------------------ |
| Name    | String   | 要创建的集合的名称          |
| Options | Document | (可选) 指定有关内存大小和索引选项 |

> 选项参数是可选的, 所以需要指定集合的唯一名字

```sql
> use test
> db.createCollection("mycollection")
-- 使用show collections命令来检查创建的集合
> show collections
> db.createCollection('mycol', {capped: true, autoIndexID: true, size: 6142800, max: 10000})
-- 在Mongodb中并不需要创建集合, 当插入一些文档Mongodb会自动创建集合
> db.newcol.insert({'name': 'test'})
```

##### 选项列表

| 字段          | 类型      | 描述                                       |
| ----------- | ------- | ---------------------------------------- |
| capped      | Boolean | (可选) 如果为true, 它启用上限集合.上限集合是一个固定大小的集合, 当它达到其最大尺寸会自动覆盖最老的条目. 如果指定为true, 则还需要指定参数的大小. |
| autoIndexID | Boolean | (可选) 如果为true, 自动创建索引_id字段. 默认值是false     |
| size        | number  | (可选) 指定的上限集合字节的最大尺寸. 如果capped是true, 那么还需要指定这个字段 |
| max         | number  | (可选) 指定上限集合允许的最大文件数                      |

#### 增删改插

```sql
-- 从数据库中删除集合
> db.COLLECTION_NAME.drop()
-- mycol 是我们的集合名称, 如果集合不存在于数据库中, 那么mongodb创建此集合, 然后插入文档进去, 如果我们不指定_id 参数插入的文档, 那么mongodb将为文档分配一个唯一的ObjectId
> db.mycol.insert({
     _id: ObjectId(7df78ad8902c),
     titile: 'mongodb overview'
  })
 -- 插入多个文档
 > db.mycol.insert([{title: 'mongodb overview'}, {title: 'nosql database'}])
```

**_id是12个字节十六进制数在一个集合的每个文档是唯一的, 划分如下**

> _id:ObjectId(4 bytes timestamp, 3bytes machine id, 2 bytes process id, 3 bytes incrementer)

```sql
-- 非结构化的方式显示所有的文件
db.COLLECTION_NAME.find()
-- 结构化显示所有文件
db.mycol.find().pretty()
-- 除了find方法还有findOne方法, 仅返回一个文档
```

mongodb 查询条件

| 操作                  | 语法                     | 示例                                 | rdbms等效语句          |
| ------------------- | ---------------------- | ---------------------------------- | ------------------ |
| Equality            | {<key>: <value>}       | db.mycol.find({"by": "yibai"})     | where by = 'yibai' |
| Less Than           | {<key>: $lt:<value>}   | db.mycol.find("likes": {$lt: 50})  | where likes < 50   |
| Less Than Equals    | {<key>:{$lte:<value>}} | db.mycol.find({"likes":{$lte:50}}) | where likes <= 50  |
| Greater Than        | {<key>:{$gt:<value>}}  | db.mycol.find({"likes":{$gt:50}})  | where likes > 50   |
| Greater Than Equals | {<key>:{$gte:<value>}} | db.mycol.find({"likes":{$gte:50}}) | where likes >= 50  |
| Not Equals          | {<key>:{$ne:<value>}}  | db.mycol.find({"likes":{$ne:50}})  | where likes != 50  |

```sql
-- and 
db.mycol.find({key1:value1, key2:value2})
-- or
db.mycol.find({$or: [{key1: value1}, {key2:value2}]})
-- and 和 or 在一起
db.mycol.find("likes": {$gt:10}, $or: [{"by": "yiibai tutorials"}, {"title": "MongoDB Overview"}] })
```

更新文档

mongodb 的update() 和save()方法用于更新文档到一个集合. update()方法将享有的文档中的值更新, 而save()方法使用传递到save()方法的文档替换现有的文档

```sql
-- db.COLLECTION_NAMEupdate((SELECTIOIN_CRITERIA, UPDATED_DATA)
db.mycol.update({'title':'MongoDB Overview'},{$set:{'title':'New MongoDB Tutorial'}})
db.COLLECTION_NAME.save({_id:ObjectId(),NEW_DATA})
```

删除文档

mongodb 的remove() 方法用于从集合中删除文档. remove()方法接受两个参数, 一个是标准缺失, 第二个是justone标志

* deletion criteria: 根据条件(可选) 删除条件将被删除
* justOne: (可选)如果设置为true或1, 然后取出只有一个文档

```sql
db.COLLECTION_NAME.remove(DELLETION_CRITTERIA)
-- 只删除一个
db.COLLECTION_NAME.remove(DELETION_CRITERIA,1)
-- 如果没有指定删除条件, 则mongodb将从集合中删除整个文件, 这相当于sql的truncate命令
```

mongodb投影

mongodb投影意义是只选择需要的数据, 而不是选择整个一个文档的数据. 如果一个文档有5个字段, 只需要显示3个, 只从中选择3个字段

```sql
db.mycol.find({},{"title":1,_id:0})
-- limit, 如果
db.COLLECTION_NAME.find().limit(NUMBER)
```

