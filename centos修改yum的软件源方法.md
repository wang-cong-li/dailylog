1. 清华大学的repo
- 访问https://mirrors.cnnic.cn/help/kubernetes/
- 根据提示操作即可
以kubernetes为例：
## RHEL/CentOS 用户
#### 新建 /etc/yum.repos.d/kubernetes.repo，内容为：
```
[kubernetes]
name=kubernetes
baseurl=https://mirrors.tuna.tsinghua.edu.cn/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
```

其中```x86_64```可换为相应的硬件架构，如```armhfp```、```aarch64```
