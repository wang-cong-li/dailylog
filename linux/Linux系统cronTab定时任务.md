# Linux系统cronTab定时任务

## 概述

要使用Linux 系统的cronTab定时任务，需要两项核心要素：

- 执行业务逻辑的```.sh```脚本
- 定时任务配置脚本```.crontab```
- cronTab常用命令

## cronTab基础知识

1. 启动基于```.crontab```配置的定时任务

   ```shell
   crontab xxx.crontab
   ```

2. 删除所有定时任务

   ```shell
   crontab -r
   ```

## 编写脚本

脚本内容：rabbitmq-top.sh

```shell
docker exec container_id top -b -n1 >> xxx.txt & date >> xxx.txt
```

## 编写定时任务配置

脚本：rabbitmq.crontab

```shell
*/1 * * * * sh x/x/rabbitmq-top.sh
```

## 同时执行多个定时任务
脚本可以改成这样：
```shell
*/1 * * * * sh x/x/rabbitmq-top.sh
*/1 * * * * sh x/x/rabbitmq-top.sh
*/1 * * * * sh x/x/rabbitmq-top.sh
```

## 启动定时任务

```shell
crontab x/x/rabbitmq.crontab
```

