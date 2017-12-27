---
layout: post
title: aws rds维护
categories: 运维
---

### Amazon RDS维护

Amazon RDS会定期对Amazon RDS资源执行维护. 维护最常设计对数据库实例或数据库集群的基础操作系统(os)的更新. 针对操作系统的大多数更新通常是因为安全问题而必须尽快进行的

维护项目需要Amazon RDS使您的数据库实例或数据库集群脱机一小段时间. 需要使资源脱机的维护包括扩展计算操作(从始至终通常只需要几分钟时间)和必需的操作系统或数据库修补. 仅对与安全性和实例可靠性相关的修补程序自动安排必需的修补. 这种修补很少发生(通常几个月一次), 并且几乎不会需要过长的维护时段.

在应用操作系统更新是, **`数据库实例不会自动备份, 所以您应该在应用更新前备份您的数据库实例`**

可以使用RDS控制台, AWS CLI或Amazon RDS API 

### 更新数据库实例或数据集群的操作系统

利用Amazon RDS, 您可以选择更新基础操作系统的时间. 您可通过使用RDS控制台, AWC Command Line Interface或RDS API来决定Amazon RDS何时应用操作系统更新. 如果某个更新可用, 则该更新将由Amazon RDS控制台上的数据库实例或数据库集群的**Maintennce**列中国的**Available**或**Required**一词指示. **如果更新可用, 则可以执行更新操作**

```shell
#查看可用更新命令
myexec aws rds --profile js describe-db-instances | jq ".DBInstances[]" | jq ".DBInstanceArn" | xargs -I {} myexec aws rds --profile hd describe-pending-maintenance-actions --resource-identifier {}
```

#### 管理数据库实例或数据库集群的操作系统更新

1. 登陆aws管理控制台 并通过一下网址打开Amazon RDS控制台<https://console.aws.amazon.com/rds/>

2. 在导航栏窗格中, 选择**Instances**来管理数据库实例更新, 或者选择**Clusters**来管理Aurora数据库集群的更新

3. 选择具有必需的操作系统更新的数据库实例或数据库集群所对应的复选框

4. 对数据库实例选择**Instance Actions**, 或者对数据库集群选择**Cluster Actions**, 然后选择一下任一操作:

   * 立即升级

   * 在下一个窗口升级

     **注意:**

     > 如果选择**upgrade at next window**, 并且以后希望延迟操作系统更新, 可以选择**Defer upgrade**

     ​


