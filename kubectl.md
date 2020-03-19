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
