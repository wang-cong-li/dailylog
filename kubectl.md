# 网上找到的kubectl安装shell命令集合
```
export APISERVER_ADVERTISE_ADDRESS=0.0.0.0
export KUBE_YAML_DIR=/etc/kubernetes/yaml/ && mkdir -p ${KUBE_YAML_DIR}


# set hostname
hostnamectl set-hostname nie-master

# Install prerequisites

cat <<EOF > /etc/yum.repos.d/paas7-crio.repo
[paas7-crio]
name=CRI-O
baseurl=https://cbs.centos.org/repos/paas7-crio-311-candidate/x86_64/os/
enabled=1
exclude=crio*
EOF

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF

# Install Package

# cri-o
yum install -y runc
yum install -y cri-o  --nogpgcheck --disableexcludes=crio

# kube*
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Change Settings

# set SELinux in permissive mode (effectively disabling it)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# probe bridge
modprobe br_netfilter

# change sysctl
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# cri-o config
sed -i 's/^cgroup_manager = "systemd"$/cgroup_manager = "cgroupfs"/' /etc/crio/crio.conf
# change default registries
sed -ie ':begin; /^#registries = \[$/,/^# \]$/ { /# \]/! { $! { N; b begin }; }; s/#registries = \[.*\]/registries = ["registry.access.redhat.com", "registry.fedoraproject.org", "docker.io"]/; };' /etc/crio/crio.conf

# Enable Service
systemctl enable crio && systemctl start crio
systemctl enable kubelet && systemctl start kubelet

# kubeadm init phase preflight 
kubeadm init phase certs all --apiserver-cert-extra-sans=apiserver.k8s.com,47.75.199.41 --service-dns-domain="nieml.k8s" --apiserver-advertise-address=${APISERVER_ADVERTISE_ADDRESS}
kubeadm init phase kubeconfig all --apiserver-advertise-address=${APISERVER_ADVERTISE_ADDRESS}
kubeadm init phase kubelet-start --cri-socket=unix:///var/run/crio/crio.sock

kubeadm init phase control-plane apiserver --apiserver-advertise-address=${APISERVER_ADVERTISE_ADDRESS} --apiserver-extra-args="service-node-port-range=1-65535"
kubeadm init phase control-plane scheduler
kubeadm init phase control-plane controller-manager --pod-network-cidr=10.244.0.0/16

# 如果需要自动分配网段 需要编辑 /etc/kubernetes/manifests/kube-controller-manager.yaml
# 在命令行里加入:  --allocate-node-cidrs=true

kubeadm init phase etcd local

kubeadm init phase mark-control-plane
kubeadm init phase bootstrap-token

kubeadm init phase addon kube-proxy --apiserver-advertise-address=${APISERVER_ADVERTISE_ADDRESS} --pod-network-cidr=10.244.0.0/16
kubeadm init phase addon coredns --service-cidr="10.96.0.0/12" --service-dns-domain="nieml.k8s"

export KUBECONFIG=/etc/kubernetes/admin.conf
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /etc/profile.d/kubernetes.sh

# kubectl taint nodes --all node-role.kubernetes.io/master-

# Install Flannel

wget https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml -O ${KUBE_YAML_DIR}/kube-flannel.yml

# apply flannel
kubectl apply -f ${KUBE_YAML_DIR}/kube-flannel.yml

# Install Dashboard

wget https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml -O ${KUBE_YAML_DIR}/kubernetes-dashboard.yaml

# generate crets
mkdir -p /etc/kubernetes/pki/dashboard/
openssl genrsa -des3 -passout pass:x -out /etc/kubernetes/pki/dashboard/dashboard.pass.key 2048
openssl rsa -passin pass:x -in /etc/kubernetes/pki/dashboard/dashboard.pass.key -out /etc/kubernetes/pki/dashboard/dashboard.key
rm -f /etc/kubernetes/pki/dashboard/dashboard.pass.key
openssl req -new -key /etc/kubernetes/pki/dashboard/dashboard.key -out /etc/kubernetes/pki/dashboard/dashboard.csr
openssl x509 -req -sha256 -days 365 -in /etc/kubernetes/pki/dashboard/dashboard.csr -signkey /etc/kubernetes/pki/dashboard/dashboard.key -out /etc/kubernetes/pki/dashboard/dashboard.crt

# create certificates secret
kubectl create secret generic kubernetes-dashboard-certs --from-file=/etc/kubernetes/pki/dashboard/ -n kube-system

# delete dashboard default certificates secret
sed -ie ':begin; /Dashboard Secret/,/^---$)/ { /^---$/! { $! { N; b begin }; }; s/Dashboard Secret.*type: Opaque\n\n---/Delete: Dashboard Secret ------------------- #/; };' ${KUBE_YAML_DIR}/kubernetes-dashboard.yaml

# change certificates parameters
sed -i 's/--auto-generate-certificates/--auto-generate-certificates=false\n          - --tls-key-file=dashboard.key\n          - --tls-cert-file=dashboard.crt/' ${KUBE_YAML_DIR}/kubernetes-dashboard.yaml

# enable nodeport
sed -ie ':begin; /^  ports:$/,/^    - port: 443$/ { /    -/! { $! { N; b begin }; }; s/  ports:.*- port: 443/  type: NodePort\n  ports:\n    - port: 443\n      nodePort: 8443/; };' ${KUBE_YAML_DIR}/kubernetes-dashboard.yaml

vim ${KUBE_YAML_DIR}/kubernetes-dashboard.yaml

# apply flannel
kubectl apply -f ${KUBE_YAML_DIR}/kubernetes-dashboard.yaml

# Join token
kubeadm init phase upload-config all
JOIN_TOKEN=`kubeadm token create`
JOIN_CERTHAST=`openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'`

echo "kubeadm join --token ${JOIN_TOKEN} apiserver.k8s.com:6443 --discovery-token-ca-cert-hash sha256:${JOIN_CERTHAST}"

# show dashboard token
kubectl -n kube-system describe `kubectl -n kube-system get secret -o name | grep dashboard-token`




# CentOS 报 /system.slice/kubelet.service 可以改 kubelet.service , 给 server 段添加下面内容即可

CPUAccounting=true
MemoryAccounting=true
```

###################################  kubeadm方式安装kubectl #######################################################
``` kubetnetes basic

交互式界面

1
https://kubernetes.io/docs/tutorials/kubernetes-basics/
　　

 

1、系统
cat /etc/redhat-release
CentOS Linux release 7.7.1908 (Core)
　　

 

# Set SELinux in permissive mode (effectively disabling it)
 
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/sysconfig/selinux
　　

2、memory　　2G

3、cpu　　　　2

4、network：public network ，private network

5、

主机名，mac，product_uuid
验证MAC地址和product_uuid对于每个节点都是唯一的

获得网络接口的MAC地址ip link或ifconfig -a

检查product_uuid sudo cat /sys/class/dmi/id/product_uuid

6、

iptalbes

确保iptables工具不使用nftables后端

7、检测所需端口

#control-plane node(s)
 
Protocol    Direction   Port Range      Purpose                     Used By
TCP         Inbound     6443*           Kubernetes API server       All
TCP         Inbound     2379-2380       etcd server client API      kube-apiserver, etcd
TCP         Inbound     10250           Kubelet API                 Self, Control plane
TCP         Inbound     10251           kube-scheduler              Self
TCP         Inbound     10252           kube-controller-manager     Self
 
 
 
#worker node(s)
 
Protocol    Direction   Port Range      Purpose                     Used By
TCP         Inbound     10250           Kubelet API                 Self, Control plane
TCP         Inbound     30000-32767     NodePort Services**         All
　　

标注*，端口可修改，标注**默认端口范围

补充:

使用pod network插件，可能需要打开某些端口，每个pod network插件情况不同

8、安装runtime

Runtime Domain Socket
Docker /var/run/docker.sock
containerd /run/containerd/containerd.sock
CRI-O /var/run/crio/crio.sock
# Install Docker CE
## Set up the repository
### Install required packages.
yum install yum-utils device-mapper-persistent-data lvm2
 
### Add Docker repository.
yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
 
## Install Docker CE.
yum update && yum install docker-ce-18.06.2.ce
 
## Create /etc/docker directory.
mkdir /etc/docker
 
# Setup daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF
 
mkdir -p /etc/systemd/system/docker.service.d
 
# Restart Docker
systemctl daemon-reload
systemctl restart docker
　　

9、

安装kubeadm，kubelet，kubectl


kubeadm：引导集群的命令

kubelet：在集群中所有node上运行的组件，执行管理pod类的操作

kubectl：与集群通信的命令行工具

1）在Linux上使用curl安装Kubectl二进制文件，这里用rpm，咱不用二进制

curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.16.0/bin/linux/amd64/kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.16.0/bin/linux/amd64/kubeadm
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.16.0/bin/linux/amd64/kubelet

2）使kubectl二进制可执行文件。

chmod +x ./kube*
　　

3）将二进制文件移到您的PATH中

sudo mv ./kube* /usr/local/bin/
　　

4）测试以确保您安装的版本是最新的
kubectl version
 
Client Version: version.Info{Major:"1", Minor:"16", GitVersion:"v1.16.0", GitCommit:"2bd9643cee5b3b3a5ecbd3af49d09018f0773c77", GitTreeState:"clean", BuildDate:"2019-09-18T14:36:53Z", GoVersion:"go1.12.9", Compiler:"gc", Platform:"linux/amd64"}
The connection to the server localhost:8080 was refused - did you specify the right host or port?
　　

10、

在control节点配置kubelet使用的cgroup驱动程序

使用docker时，kubeadm将自动检测kubelet的cgroup驱动程序并在运行时将其设置在文件/var/lib/kubelet/kubeadm-flags.env中
KUBELET_EXTRA_ARGS=--cgroup-driver=cgroupfs
systemctl daemon-reload
systemctl restart kubelet
　　

使用kubeadm创建单个控制集群

支持时间表
Kubernetes版本        发行月份        生命终结月
v1.13.x         2018年12月        2019年9月 
v1.14.x         2019年3月     2019年12月 
v1.15.x         2019年6月     2020年3月 
v1.16.x         2019年9月     2020年6月   
　　

1）CentOS 7上的一些用户报告了由于绕过iptables而导致流量无法正确路由的问题。您应该确保 net.bridge.bridge-nf-call-iptables在sysctl配置中将其设置为1

 

先确保模块br_netfilter已被加载
lsmod | grep br_netfilter
 
modprobe br_netfilter
 
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
 
sysctl --system
　　

2）通过google的rpm包安装
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
 
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
 
systemctl enable --now kubelet
　　

在kubeadm init之前验证与gcr.io的连接

1
kubeadm  config images pull
　　

准备所需docker image：
REPOSITORY                           TAG                 IMAGE ID            CREATED             SIZE
k8s.gcr.io/kube-proxy                v1.16.1             0d2430db3cd0        9 days ago          86.1MB
k8s.gcr.io/kube-apiserver            v1.16.1             f15aad0426f5        9 days ago          217MB
k8s.gcr.io/kube-controller-manager   v1.16.1             ba306669806e        9 days ago          163MB
k8s.gcr.io/kube-scheduler            v1.16.1             e15192a92182        9 days ago          87.3MB
k8s.gcr.io/etcd                      3.3.15-0            b2756210eeab        5 weeks ago         247MB
k8s.gcr.io/coredns                   1.6.2               bf261d157914        8 weeks ago         44.1MB
k8s.gcr.io/pause                     3.1                 da86e6ba6ca1        22 months ago       742kB
　　

循环导入

for i in `ls ` ;do docker load < $i ;done
　　

初始化control-plane节点
kubeadm init 
 
--control-plane-endpoint  做高可用应指定负载均衡的dns名称或ip地址
 
--pod-network-cidr
选择pod network插件<br>不同网络方案有自己的网络地址要求
 
--cri-socket
指定不同容器runtime
 
--apiserver-advertise-address=10.1.1.91
control节点apiserver的公布地址
指明master的哪个interface与cluster的其它节点通信，如果不指定，kubeadm会自动选择有默认网关的interface
 
--control-plane-endpoint=cluster-endpoint
设置控制节点的共享端点（即vip），IP地址或dns名称
 
如：
 
10.1.1.91  cluster-endpoint
 
cluster-endpoint的映射，后续方便修改为高可用方案中的负载均衡器地址
/etc/sysconfig/kubelet
 
KUBELET_EXTRA_ARGS="--fail-swap-on=false"
kubeadm init --kubernetes-version=v1.16.1 \
--apiserver-advertise-address=10.1.1.91  \
--apiserver-bind-port=6443 \
--cert-dir=/etc/kubernetes/pki \
--control-plane-endpoint=cluster-endpoint  \
--pod-network-cidr=10.10.0.0/16 \
--service-cidr=10.96.0.0/12 \
--ignore-preflight-errors=Swap
 
注意：
--cert-dir=/etc/kubernetes/pki  #各节点的该目录要保持一致，我这边在部署时目录名手动写的，与默认的kubernetes不一致，导致后面worker node持续找不到ca.crt
　　

输出
[init] Using Kubernetes version: v1.16.1
[preflight] Running pre-flight checks　　#初始化前检查
    [WARNING Swap]: running with swap on is not supported. Please disable swap
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Activating the kubelet service
[certs] Using certificateDir folder "/etc/kubenets/pki"
[certs] Generating "ca" certificate and key　　#生成证书
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [vm1 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local cluster-endpoint] and IPs [10.96.0.1 10.1.1.91]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [vm1 localhost] and IPs [10.1.1.91 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [vm1 localhost] and IPs [10.1.1.91 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file　　#生成kubeconfig,kubelet通过它与master通信
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 23.006210 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.16" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node vm1 as control-plane by adding the label "node-role.kubernetes.io/master=''"
[mark-control-plane] Marking the node vm1 as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: xqm7m0.b5kte1w4is1wy0a1
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy
 
Your Kubernetes control-plane has initialized successfully!　　#kubernetes master初始化成功
 
To start using your cluster, you need to run the following as a regular user:　　#提示如何配置kubectl
 
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
 
You should now deploy a pod network to the cluster.　　　　#安装pod网络
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:　　
  https://kubernetes.io/docs/concepts/cluster-administration/addons/
 
You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:
 
  kubeadm join cluster-endpoint:6443 --token xqm7m0.b5kte1w4is1wy0a1 \
    --discovery-token-ca-cert-hash sha256:ac0fc57d71c6322d2fca7c71b55aeb7f20d6eb97fe8baa9cd6b5b7069fc8a88c \
    --control-plane      
 
Then you can join any number of worker nodes by running the following on each as root:
 
kubeadm join cluster-endpoint:6443 --token xqm7m0.b5kte1w4is1wy0a1 \
    --discovery-token-ca-cert-hash sha256:ac0fc57d71c6322d2fca7c71b55aeb7f20d6eb97fe8baa9cd6b5b7069fc8a88c
　　

网络选择calico
kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
　　

输出
configmap/calico-config created
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ippools.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networksets.crd.projectcalico.org created
clusterrole.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrolebinding.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrole.rbac.authorization.k8s.io/calico-node created
clusterrolebinding.rbac.authorization.k8s.io/calico-node created
daemonset.apps/calico-node created
serviceaccount/calico-node created
deployment.apps/calico-kube-controllers created
serviceaccount/calico-kube-controllers created
　　

确认calico所涉及image
calico/node                          v3.8.2              11cd78b9e13d        2 months ago        189MB
calico/cni                           v3.8.2              c71c24a0b1a2        2 months ago        157MB
calico/kube-controllers              v3.8.2              de959d4e3638        2 months ago        46.8MB
calico/pod2daemon-flexvol            v3.8.2              96047edc008f        2 months ago        9.37MB
　　

检查状态
[root@vm1 ~]# kubectl get node
NAME   STATUS   ROLES    AGE   VERSION
vm1    Ready    master   31m   v1.16.1
 
[root@vm1 /]# kubectl get cs
NAME                 AGE
controller-manager   <unknown>
scheduler            <unknown>
etcd-0               <unknown>
　　

查看资源对象
[root@vm1 ~]# kubectl -n kube-system get  deploy
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
calico-kube-controllers   1/1     1            1           21m
coredns                   2/2     2            2           35m
 
 
[root@vm1 ~]# kubectl -n kube-system get pods
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-564b6667d7-kmlkw   1/1     Running   0          21m
calico-node-r9fr7                          1/1     Running   0          21m
coredns-5644d7b6d9-5qzvm                   1/1     Running   0          35m
coredns-5644d7b6d9-kckm7                   1/1     Running   0          35m
etcd-vm1                                   1/1     Running   0          35m
kube-apiserver-vm1                         1/1     Running   0          35m
kube-controller-manager-vm1                1/1     Running   0          35m
kube-proxy-xjs7n                           1/1     Running   0          35m
kube-scheduler-vm1                         1/1     Running   0          34m
　　

infrastructure image的指定
[root@vm1 ~]# cat /var/lib/kubelet/kubeadm-flags.env
KUBELET_KUBEADM_ARGS="--cgroup-driver=systemd --network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.1"
　　

默认情况下，处于安全原因，cluster不会在control-plane node上调度pod，若希望在此节点调度，请运行
kubectl taint nodes --all node-role.kubernetes.io/master-
　　

这样就意味着，所有节点将移除污点，都可以被调度

 

worker node  的加入
kubeadm join cluster-endpoint:6443 --token xqm7m0.b5kte1w4is1wy0a1 \
    --discovery-token-ca-cert-hash sha256:ac0fc57d71c6322d2fca7c71b55aeb7f20d6eb97fe8baa9cd6b5b7069fc8a88c \
    --ignore-preflight-errors=Swap
　　

注意：我的ca.crt是手动从control-plane node拷贝过来的

 

输出：
[preflight] Running pre-flight checks
    [WARNING Swap]: running with swap on is not supported. Please disable swap
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
W1014 16:03:38.259243   10784 common.go:138] WARNING: could not obtain a bind address for the API Server: no default routes found in "/proc/net/route" or "/proc/net/ipv6_route"; using: 0.0.0.0
[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.16" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Activating the kubelet service
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...
 
This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.
 
Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
　　

 查看集群
[root@vm1 ~]# kubectl get nodes
NAME   STATUS   ROLES    AGE     VERSION
vm1    Ready    master   7d23h   v1.16.1
vm2    Ready    <none>   7d18h   v1.16.1
vm3    Ready    <none>   7d17h   v1.16.1
　　

标记vm2,vm3的role为node
[root@vm1 ~]# kubectl label node vm2  node-role.kubernetes.io/node='node'
node/vm2 labeled
[root@vm1 ~]# kubectl label node vm3  node-role.kubernetes.io/node='node'
node/vm3 labeled
　　

再次确认

[root@vm1 ~]# kubectl get nodes
NAME   STATUS   ROLES    AGE     VERSION
vm1    Ready    master   7d23h   v1.16.1
vm2    Ready    node     7d18h   v1.16.1
vm3    Ready    node     7d17h   v1.16.1
 

从非control node来控制集群，需要admin.conf

临时指定config访问
kubectl --kubeconfig ./admin.conf get nodes
　　

固化
To start using your cluster, you need to run the following as a regular user:　　#提示如何配置kubectl
 
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

对control-plane node做高可用

添加第二个control-plane node
kubeadm join cluster-endpoint:6443 --token xqm7m0.b5kte1w4is1wy0a1 \
  --discovery-token-ca-cert-hash sha256:ac0fc57d71c6322d2fca7c71b55aeb7f20d6eb97fe8baa9cd6b5b7069fc8a88c \
  --control-plane --apiserver-advertise-address=10.1.1.92 --ignore-preflight-errors=Swap
　　

添加第三个control-plane node
kubeadm join cluster-endpoint:6443 --token xqm7m0.b5kte1w4is1wy0a1 \
  --discovery-token-ca-cert-hash sha256:ac0fc57d71c6322d2fca7c71b55aeb7f20d6eb97fe8baa9cd6b5b7069fc8a88c \
  --control-plane --apiserver-advertise-address=10.1.1.93 --ignore-preflight-errors=Swap
  ```
