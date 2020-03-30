## jenkins自动化部署配置详细说明



### pipeline方式

#### jenkins配置调整

##### 1.设置jenkins运行用户为root

```sh
# 1.将jenkins账号分别加入到root组中
gpasswd -a jenkins root
# 2.修改/etc/sysconfig/jenkins文件中，
# user id to be invoked as (otherwise will run as root; not wise!)
JENKINS_USER=root
JENKINS_GROUP=root
```

##### 设置jenkins的启动端口

> 首先查看机器上端口占用情况  ``` netstat -anp ``` ，如果要查看某个特定的端口是否被占用(以10000端口为例)：``` netstat -anp | grep 10000 ```，如果命令输出 ``` unix  3      [ ]         流        已连接     34523    3120/polkit-gnome-a ```,说明端口已经被占用；如果无任何内容输出，则端口空闲，可以设置为jenkins的启动端口

修改/etc/sysconfig/jenkins文件中 ```HTTP_PORT=9070```,这样jenkins启动就可以以9070端口启动

#### jenkins配置样板

```  javascript
## Description: Jenkins Automation Server
## Type:        string
## Default:     "/var/lib/jenkins"
## ServiceRestart: jenkins
#
# Directory where Jenkins store its configuration and working
# files (checkouts, build reports, artifacts, ...).
#
JENKINS_HOME="/var/lib/jenkins"

## Type:        string
## Default:     ""
## ServiceRestart: jenkins
#
# Java executable to run Jenkins
# When left empty, we'll try to find the suitable Java.
#
JENKINS_JAVA_CMD=""

## Type:        string
## Default:     "jenkins"
## ServiceRestart: jenkins
#
# Unix user account that runs the Jenkins daemon
# Be careful when you change this, as you need to update
# permissions of $JENKINS_HOME and /var/log/jenkins.
#
JENKINS_USER="root"
JENKINS_GROUP="root"
## Type:        string
## Default: "false"
## ServiceRestart: jenkins
#
# Whether to skip potentially long-running chown at the
# $JENKINS_HOME location. Do not enable this, "true", unless
# you know what you're doing. See JENKINS-23273.
#
#JENKINS_INSTALL_SKIP_CHOWN="false"

## Type: string
## Default:     "-Djava.awt.headless=true"
## ServiceRestart: jenkins
#
# Options to pass to java when running Jenkins.
#
JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true"

## Type:        integer(0:65535)
## Default:     8080
## ServiceRestart: jenkins
#
# Port Jenkins is listening on.
# Set to -1 to disable
#
JENKINS_PORT="9070"

## Type:        string
## Default:     ""
## ServiceRestart: jenkins
#
# IP address Jenkins listens on for HTTP requests.
# Default is all interfaces (0.0.0.0).
#
JENKINS_LISTEN_ADDRESS=""

## Type:        integer(0:65535)
## Default:     ""
## ServiceRestart: jenkins
#
# HTTPS port Jenkins is listening on.
# Default is disabled.
#
JENKINS_HTTPS_PORT="8443"

## Type:        string
## Default:     ""
## ServiceRestart: jenkins
#
# Path to the keystore in JKS format (as created by the JDK 'keytool').
# Default is disabled.
#
JENKINS_HTTPS_KEYSTORE=""

## Type:        string
## Default:     ""
## ServiceRestart: jenkins
#
# Password to access the keystore defined in JENKINS_HTTPS_KEYSTORE.
# Default is disabled.
#
JENKINS_HTTPS_KEYSTORE_PASSWORD=""

## Type:        string
## Default:     ""
## ServiceRestart: jenkins
#
# IP address Jenkins listens on for HTTPS requests.
# Default is disabled.
#
JENKINS_HTTPS_LISTEN_ADDRESS=""

## Type:        integer(0:65535)
## Default:     ""
## ServiceRestart: jenkins
#
# HTTP2 port Jenkins is listening on.
# Default is disabled.
#
# Notice: HTTP2 support may require additional configuration, see Winstone
# documentation for more information.
#
JENKINS_HTTP2_PORT=""

## Type:        string
## Default:     ""
## ServiceRestart: jenkins
#
# IP address Jenkins listens on for HTTP2 requests.
# Default is disabled.
#
# Notice: HTTP2 support may require additional configuration, see Winstone
# documentation for more information.
#
JENKINS_HTTP2_LISTEN_ADDRESS=""

## Type:        integer(1:9)
## Default:     5
## ServiceRestart: jenkins
#
# Debug level for logs -- the higher the value, the more verbose.
# 5 is INFO.
#
JENKINS_DEBUG_LEVEL="5"

## Type:        yesno
## Default:     no
## ServiceRestart: jenkins
#
# Whether to enable access logging or not.
#
JENKINS_ENABLE_ACCESS_LOG="no"

## Type:        integer
## Default:     100
## ServiceRestart: jenkins
#
# Maximum number of HTTP worker threads.
#
JENKINS_HANDLER_MAX="100"

## Type:        integer
## Default:     20
## ServiceRestart: jenkins
#
# Maximum number of idle HTTP worker threads.
#
JENKINS_HANDLER_IDLE="20"

## Type:        string
## Default:     ""
## ServiceRestart: jenkins
#
# Folder for additional jar files to add to the Jetty class loader.
# See Winstone documentation for more information.
# Default is disabled.
#
JENKINS_EXTRA_LIB_FOLDER=""

## Type:        string
## Default:     ""
## ServiceRestart: jenkins
#
# Pass arbitrary arguments to Jenkins.
# Full option list: java -jar jenkins.war --help
#
JENKINS_ARGS=""
```

#### jenkins启动

centos系统使用命令：``` sudo service jenkins start ```

centos系统停止jenkins命令：：``` sudo service jenkins stop ```

centos系统重启jenkins命令：：``` sudo service jenkins restart ```

我们测试服务器的jenkins地址是：``` http://192.168.2.114:9070```

#### jenkins工作目录

保持默认就可以了，一般工作目录为``` /var/lib/jenkins/workspace/ ``` 

如果需要修改的话：修改/etc/sysconfig/jenkins文件中 ```JENKINS_HOME=/var/lib/jenkins```

#### jenkins初始启动

此安装向导会引导您完成几个快速“一次性”步骤来解锁Jenkins， 使用插件对其进行自定义，并创建第一个可以继续访问Jenkins的管理员用户。

###### 解锁jenkins

当您第一次访问新的Jenkins实例时，系统会要求您使用自动生成的密码对其进行解锁。

浏览到 http://192.168.2.114:9070（或安装时为Jenkins配置的任何端口），并等待解锁 Jenkins 页面出现。

解锁页面如下:

![1579242942(1)](C:\Users\centlee\Desktop\1579242942(1).png)

根据提示打开/var/jenkins_home/secrets/initialAdminPassword,可以看到生成的初始密码，填入文本框，点击下一步，解锁 Jenkins之后，在 Customize Jenkins 页面内， 您可以安装任何数量的有用插件作为您初始步骤的一部分。

会看到如下页面：

![](C:\Users\centlee\Desktop\1579243651(1).png)

两个选项可以设置:

安装建议的插件 - 安装推荐的一组插件，这些插件基于最常见的用例.

选择要安装的插件 - 选择安装的插件集。当你第一次访问插件选择页面时，默认选择建议的插件。

如果您不确定需要哪些插件，请选择 安装建议的插件 。 您可以通过Jenkins中的Manage Jenkins

\> Manage Plugins 页面在稍后的时间点安装（或删除）其他Jenkins插件 。

设置向导显示正在配置的Jenkins的进程以及您正在安装的所选Jenkins插件集。这个过程可能需要几分钟时间

#### jenkins插件管理

要实现jenkins和github server的联动，必须具有以下几个插件：

- Build Authorization Token Root Plugin
- Build Authoration Token Root
- Publish Over SSH
- Gitlab Authentication

#### jenkins全局配置



#### jenkins新建工程流水线步骤

##### 流水线概念

请参考：[pipeline概念][pipeline概念网址]

###### 操作步骤

[pipeline概念网址]:https://jenkins.io/zh/doc/book/pipeline/

![1579247060](C:\Users\centlee\Desktop\1579247158(1).png)

![1579247252(1)](C:\Users\centlee\Desktop\1579247252(1).png)

![1579247317(1)](C:\Users\centlee\Desktop\1579247317(1).png)

最后，在上图的pipeline编辑区中填入代码，点击保存一个pipeline就完成了。

#### jenkins编辑流水线pipeline代码

使用java的demo程序作为示例：

其pipeline代码如下：

### jenkins和GitHub server联动配置

#### jenkins配置

#### github server配置

### maven方式