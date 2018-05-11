---
title: "Setting up a Kubernetes cluster with Vagrant"
description: "Setup a kubernetes cluster with one key and addons included."
bref: "Using vagrant file to build a kubernetes cluster which consists of 1 master(also as node) and 3 nodes. You don't have to create complicated ca files or configuration"
toc: true
date: 2018-05-11T23:26:36+08:00
draft: false
---

[See in GitHub](https://github.com/rootsongjc/kubernetes-vagrant-centos-cluster/)

Using vagrant file to build a kubernetes cluster which consists of 1 master(also as node) and 3 nodes. You don't have to create complicated ca files or configuration.

### Why don't we use kubeadm

Because I want to setup the etcd, apiserver, controller, scheduler without docker container.

### Architecture

We will create a Kubernetes 1.9.1+ cluster with 3 nodes which contains the components below:

| IP           | Hostname | Componets                                                    |
| ------------ | -------- | ------------------------------------------------------------ |
| 172.17.8.101 | node1    | kube-apiserver, kube-controller-manager, kube-scheduler, etcd, kubelet, docker, flannel, dashboard |
| 172.17.8.102 | node2    | kubelet, docker, flannel、traefik                            |
| 172.17.8.103 | node3    | kubelet, docker, flannel                                     |

The default setting will create the private network from 172.17.8.101 to 172.17.8.103 for nodes, and it will use the host's DHCP for the public ip.

The kubernetes service's vip range is `10.254.0.0/16`.

The container network range is `170.33.0.0/16` owned by flanneld with `host-gw` backend.

`kube-proxy` will use `ipvs` mode.

### Usage

#### Prerequisite

- Host server with 8G+ mem(More is better), 60G disk, 8 core cpu at lease
- vagrant 2.0+
- virtualbox 5.0+
- Maybe need to access the internet through GFW to download the kubernetes files

#### Support Addon

**Required**

- CoreDNS
- Dashboard
- Traefik

**Optional**

- Heapster + InfluxDB + Grafana
- ElasticSearch + Fluentd + Kibana
- Istio service mesh
- Helm

#### Setup

Download kubernetes binary release first and move them to this git repo.

```bash
git clone https://github.com/rootsongjc/kubernetes-vagrant-centos-cluster.git
cd kubernetes-vagrant-centos-cluster
vagrant up
```

Before you run `vagrant up` make sure this repo directory include the flowing files:

- kubernetes-client-linux-amd64.tar.gz
- kubernetes-server-linux-amd64.tar.gz

Wait about 10 minutes the kubernetes cluster will be setup automatically.

**Note**

If you have difficult to vagrant up the cluster because of have no way to downlaod the `centos/7` box, you can download the box and add it first.

**Add centos/7 box manually**

```bash
wget -c http://cloud.centos.org/centos/7/vagrant/x86_64/images/CentOS-7-x86_64-Vagrant-1801_02.VirtualBox.box
vagrant box add CentOS-7-x86_64-Vagrant-1801_02.VirtualBox.box --name centos/7
```

The next time you run `vagrant up`, vagrant will import the local box automatically.

#### Connect to kubernetes cluster

There are 3 ways to access the kubernetes cluster.

**local**

Copy `conf/admin.kubeconfig` to `~/.kube/config`, using `kubectl` CLI to access the cluster.

```
mkdir -p ~/.kube
cp conf/admin.kubeconfig ~/.kube/config
```

We recommend this way.

**VM**

Login to the virtual machine to access and debug the cluster.

```bash
vagrant ssh node1
sudo -i
kubectl get nodes
```

**Kubernetes dashbaord**

Kubernetes dashboard URL: [https://172.17.8.101:8443](https://172.17.8.101:8443/)

Get the token:

```bash
kubectl -n kube-system describe secret `kubectl -n kube-system get secret|grep admin-token|cut -d " " -f1`|grep "token:"|tr -s " "|cut -d " " -f2
```

**Note**: You can see the token message from `vagrant up` logs.

### Components installed

**Heapster monitoring**

Run this command on you local machine.

```bash
kubectl apply -f addon/heapster/
```

Append the following item to you local `/etc/hosts` file.

```bash
172.17.8.102 grafana.jimmysong.io
```

Open the URL in your browser: [http://grafana.jimmysong.io](http://grafana.jimmysong.io/)

**Treafik ingress**

Run this command on you local machine.

```bash
kubectl apply -f addon/traefik-ingress
```

Append the following item to you local `/etc/hosts` file.

```bash
172.17.8.102 traefik.jimmysong.io
```

Traefik UI URL: [http://traefik.jimmysong.io](http://traefik.jimmysong.io/)

**EFK**

Run this command on your local machine.

```bash
kubectl apply -f addon/heapster/
```

**Note**: Powerful CPU and memory allocation required. At least 4G per virtual machine.

**Helm**

Run this command on your local machine.

```bash
hack/deploy-helm.sh
```

#### Service Mesh

We use [istio](https://istio.io/) as the default service mesh.

**Installation**

```bash
kubectl apply -f addon/istio/
```

**Run sample**

```bash
kubectl apply -n default -f <(istioctl kube-inject -f yaml/istio-bookinfo/bookinfo.yaml)
```

Add the following items into `/etc/hosts` in your local machine.

```bash
172.17.8.102 grafana.istio.jimmysong.io
172.17.8.102 servicegraph.istio.jimmysong.io
172.17.8.102 zipkin.istio.jimmysong.io
```

We can see the services from the following URLs.

| Service      | URL                                                          |
| ------------ | ------------------------------------------------------------ |
| grafana      | [http://grafana.istio.jimmysong.io](http://grafana.istio.jimmysong.io/) |
| servicegraph | <http://servicegraph.istio.jimmysong.io/dotviz>, <http://servicegraph.istio.jimmysong.io/graph> |
| zipkin       | [http://zipkin.istio.jimmysong.io](http://zipkin.istio.jimmysong.io/) |
| productpage  | <http://172.17.8.101:32000/productpage>                      |

More detail see <https://istio.io/docs/guides/bookinfo.html>

### Operation

Except for special claim, execute the following commands under the current git repo root directory.

#### Suspend

Suspend the current state of VMs.

```bash
vagrant suspend
```

#### Resume

Resume the last state of VMs.

```bash
vagrant resume
```

Note: every time you resume the VMs you will find that the machine time is still at you last time you suspended it. So consider to halt the VMs and restart them.

#### Restart

Halt the VMs and up them again.

```bash
vagrant halt
vagrant up
# login to node1
vagrant ssh node1
# run the prosivision scripts
/vagrant/hack/k8s-init.sh
exit
# login to node2
vagrant ssh node2
# run the prosivision scripts
/vagrant/hack/k8s-init.sh
exit
# login to node3
vagrant ssh node3
# run the prosivision scripts
/vagrant/hack/k8s-init.sh
sudo -i
cd /vagrant/hack
./deploy-base-services.sh
exit
```

Now you have provisioned the base kubernetes environments and you can login to kubernetes dashboard, run the following command at the root of this repo to get the admin token.

```bash
hack/get-dashboard-token.sh
```

Following the hint to login.

#### Clean

Clean up the VMs.

```bash
vagrant destroy
rm -rf .vagrant
```

#### Note

Only use for development and test, don't use it in production environment.

### Reference

- [Kubernetes Handbook - jimmysong.io](https://jimmysong.io/kubernetes-handbook/)
- [duffqiu/centos-vagrant](https://github.com/duffqiu/centos-vagrant)
- [kubernetes ipvs](https://github.com/kubernetes/kubernetes/tree/master/pkg/proxy/ipvs)