# MySQL数据导入和导出命令详解
## 数据导入
- 直接执行sql导入数据，适用于在同一个数据库中将数据从一个表导入到另一个新建表
- 使用source命令，将sql文件导入数据库，前提是必须有现成的sql文件，适用于跨库进行数据导入或者数据量比较大的情况
### 直接执行sql导入数据
#### 在同数据库下复制一个表的数据到另一个表
> 在日常工作中，经常会碰到这种场景：我们有一个表已经在使用中了，里面已经有数据若干条，这时由于各种原因要重命名表名。
  这时就需要使用新表名建新表，表名和字段和原表一致，然后将旧表数据导入到新表，完成后删除旧表。

下面我们上代码：

```sql
-- 假设我们现在有张表叫user_temp
-- 表字段有user_id,user_name
-- 现在我们要将表重命名为user
-- 1.创建user表,字段和user_temp保持一致
create table user {
   user_id int(8) primary key auto_increment,
   user_name varchar(128) not null
} engine=innodb,character-set=utf8;
-- 2.将user_temp中数据导入到user
insert into user select * from user_temp;
-- 3.删除user_temp表
drop table user_temp;

```

或者

```sql
create table user select * from user_temp;
```

##### 有时候我们只需要导某些字段的数据，而不是全表

此时：

```sql
INSERT INTO user (user_name) SELECT user_name FROM user_temp;
```

### 跨库进行库和表的数据复制

可以使用mysqldump命令将指定的数据库或数据表导出为sql或者csv等等，然后将数据拷贝到对应的机器，执行source命令或者load data命令将数据导入到对应的数据库或数据表

#### 通过sql文件

> 表名不一致情况

```mysql
-- 假设我们现在有张表叫user_temp
-- 表字段有user_id,user_name
-- 现想将数据导入到另外一个库的user表中
-- 1. 导出数据
mysqldump --h192.168.2.1 -uroot -p123456 --default-character-set=utf8 --database db0 --tables user_temp > /usr/local/backup/1.sql
-- 2.将/usr/local/backup/1.sql放到指定的机器上
-- 3.如果我们想将数据导入的表和原表名不一致
mysql -uroot -p123456;
load   data   infile   /usr/local/backup/1.sql  into  table user;
```

> 表名一致的情况

```mysql
-- 假设我们现在有张表叫user_temp
-- 表字段有user_id,user_name
-- 现想将数据导入到另外一个库的user表中
-- 1. 导出数据
mysqldump --h192.168.2.1 -uroot -p123456 --default-character-set=utf8 --database db0 --tables user_temp > /usr/local/backup/1.sql
-- 2.将/usr/local/backup/1.sql放到指定的机器上
-- 3.如果我们想将数据导入的表和原表名不一致
mysql -uroot -p123456;
source   /usr/local/backup/1.sql ;
```

#### 直接跨机器导入数据

```mysql
-- 将h1服务器中的db1数据库的所有数据导入到h2中的db2数据库中，db2的数据库必须存在否则会报错
mysqldump --host=h1 -uroot -proot --databases db1 |mysql --host=h2 -uroot -proot db2
```

