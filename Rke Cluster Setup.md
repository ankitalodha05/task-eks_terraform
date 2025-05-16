# Step-by-Step Guide: Kubernetes Cluster Setup Using RKE on AWS

This guide details the steps followed to create a Kubernetes cluster using Rancher Kubernetes Engine (RKE) on 3 Ubuntu EC2 servers.

---

## Prerequisites

* 3 Ubuntu EC2 instances launched:

  * **Master Node**: `t2.medium` (13.201.92.199)
  * **Worker Node**: `t2.micro` (15.207.111.88)
  * **ETCD Node**: `t2.micro` (13.234.21.100)
* A PEM key file: `ankita.pem`
* All instances have Docker installed and user `ubuntu` has permissions to run Docker

---

## Step 1: Install Docker on All Servers

SSH into each instance and run:

```bash
sudo apt update -y
sudo apt install docker.io -y
sudo usermod -aG docker ubuntu
sudo systemctl enable docker && sudo systemctl start docker
```

Logout and log back in to activate group changes.

---

## Step 2: Prepare Local System (WSL/Ubuntu)

### Download and install RKE:

```bash
wget https://github.com/rancher/rke/releases/download/v1.8.3/rke_linux-amd64
mv rke_linux-amd64 rke
chmod +x rke
mv rke /usr/sbin/
```

### Create working directory:

```bash
mkdir rancher && cd rancher
```

### Place your SSH private key file:

```bash
cp /path/to/ankita.pem /root/ankita.pem
chmod 400 /root/ankita.pem
```

---

## Step 3: Generate Cluster Configuration

```bash
rke config
```

* Use the following inputs:

  * SSH Key: `/root/ankita.pem`
  * Hosts:

    * `13.201.92.199`: controlplane, worker
    * `15.207.111.88`: worker
    * `13.234.21.100`: etcd

This creates a `cluster.yml` file.

---

## Step 4: Bring Up the Kubernetes Cluster

```bash
rke up
```

* This will:

  * Validate SSH access
  * Deploy controlplane, etcd, worker components
  * Install CoreDNS, Metrics Server, and NGINX ingress controller
  * Generate: `kube_config_cluster.yml`

---

## Step 5: Configure kubectl Access

```bash
mkdir -p ~/.kube
mv /root/rancher/kube_config_cluster.yml ~/.kube/config
chmod 600 ~/.kube/config
```

---

## Step 6: Verify Cluster

```bash
kubectl get nodes
```

Expected output:

```
NAME            STATUS   ROLES          AGE    VERSION
13.201.92.199   Ready    controlplane   ...    v1.32.4
13.234.21.100   Ready    etcd           ...    v1.32.4
15.207.111.88   Ready    worker         ...    v1.32.4
```

---
-![image](https://github.com/user-attachments/assets/63b03211-5b42-4dd1-ba76-ded04c2024b7)


## ✅ Cluster Setup Complete!

You can now deploy applications, Helm charts, or Rancher UI for managing the cluster.

---
