Jenkins 运行权限问题

yum安装的Jenkins 配置文件默认位置/etc/sysconfig/jenkins
默认jenkins服务以jenkins用户运行，这时在jenkins执行ant脚本时可能会发生没有权限删除目录，覆盖文件等情况。可以让jenkins以root用户运行来解决这个问题。

1.将jenkins账号分别加入到root组中
gpasswd -a jenkins root

2.修改/etc/sysconfig/jenkins文件中，
#user id to be invoked as (otherwise will run as root; not wise!)
JENKINS_USER=root
JENKINS_GROUP=root

可以修改为root权限运行