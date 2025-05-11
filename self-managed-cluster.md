# Kubernetes Cluster Setup on AWS EC2 (1 Master, 1 Worker)

This document provides a step-by-step guide to create a Kubernetes cluster with one master (controller) and one worker node on AWS EC2 Ubuntu instances. The setup includes Docker, containerd, kubeadm, kubelet, and kubectl. It also provides user-data automation scripts for both master and worker nodes.

---

## Prerequisites

* AWS account with permissions to create EC2 instances
* SSH key pair created in the AWS region
* Default VPC or custom VPC with at least one public subnet
* Security group allowing:

  * SSH (port 22)
  * Kubernetes ports: 6443, 10250, 30000-32767

---

## Step 1: Launch EC2 Ubuntu 22.04 Instances

Create **two** EC2 instances with Ubuntu 22.04:

* **Master Node**: `t2.medium` or higher
* **Worker Node**: `t2.medium` or higher

Use the respective user-data scripts below while launching.

---

## Step 2: User Data Script - Master Node

Use this script in the EC2 launch wizard (Advanced details > user data):

```bash
#!/bin/bash
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

apt-get update && apt-get dist-upgrade -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg inetutils-traceroute

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo ${UBUNTU_CODENAME}) stable" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu

modprobe overlay
modprobe br_netfilter
echo -e "overlay\nbr_netfilter" > /etc/modules-load.d/k8s.conf
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/k8s.conf
sysctl --system

containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=1.30.2-1.1 kubeadm=1.30.2-1.1 kubectl=1.30.2-1.1
apt-mark hold kubelet kubeadm kubectl

kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=1.30.2

mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

su - ubuntu -c "kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"
```

---

## Step 3: User Data Script - Worker Node

Use this script in the EC2 launch wizard (Advanced details > user data):

```bash
#!/bin/bash
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

apt-get update && apt-get dist-upgrade -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg inetutils-traceroute

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo ${UBUNTU_CODENAME}) stable" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu

modprobe overlay
modprobe br_netfilter
echo -e "overlay\nbr_netfilter" > /etc/modules-load.d/k8s.conf
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/k8s.conf
sysctl --system

containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=1.30.2-1.1 kubeadm=1.30.2-1.1 kubectl=1.30.2-1.1
apt-mark hold kubelet kubeadm kubectl
```

---

## Step 4: Join Worker Node to Cluster

On the master node, generate the join command:

```bash
kubeadm token create --print-join-command
```

Copy the output, then SSH into the worker node and run it. Example:

```bash
sudo kubeadm join 172.31.16.123:6443 --token i9lgey.6x1qjeu3ug1tq7a9 --discovery-token-ca-cert-hash sha256:7efe0436c005f99df91c8db914eff2201a138de2c50e78f200a3e2cb58925718
```

---

## Step 5: Verify Cluster

On the master node:

```bash
kubectl get nodes
```

You should see both the master and worker nodes in the `Ready` state.

---

## ✅ Cluster is Ready!

You can now deploy apps, test workloads, or install monitoring/logging tools.
