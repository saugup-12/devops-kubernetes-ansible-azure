# kubernetes-ansible-azure

## What it is this?
The target of this project is to deploy and maintain a Kubernetes Cluster on Azure, using CentOS7.2 as the OS and Ansible+kubeadm for deployment. 

## Why not use any of the existing solutions?
I found multiple solutions to deploy Kubernetes to different cloud providers, including Azure. Some were outdated or incomplete, some were too complicated in my humble opinion. The too complicated ones predate the release of "kubeadm". kubeadm seems to become the standard in cluster deployment and makes deployment a lot easier, especially when it comes to certificate management.

## Getting started
Setting up a Kubernetes cluster with this Ansible project consists of multiple steps. 

1. First, you have to create an Azure Resource Group inside of your Azure subscription. Please read through the Azure docs or contact your Azure administrator for this.
2. You need an Azure Service Principal Account and appropriate credentials for the SP. Please read through https://azure.microsoft.com/en-us/documentation/articles/resource-group-create-service-principal-portal/ to figure out how to create one. The SP is used to setup the Azure resources with Azure Resource Templates and is also later used by the Kubernetes Cloud Provider to modify resources as needed (e.g. Routing Table entries, Load Balancers, ...)
3. Please make a copy of azure_creds.env.example, name it azure_creds.env and put your SP credentials into this file. You will also need to add the resource group name and resource location.
4. Please edit group_vars/all to include your custom admin password and your own ssh public key. Please also make sure the private key is known to the SSH Agent. I will probably automate this part later.
5. Before executing anything from this Ansible project, you'll have to source in the Azure credentials:
    ```
    # source ./azure_creds.env
    ```
6. To generate the Azure Resource Templates and apply them to your Resource Group, call "./apply-rg.sh". This will take quite some time, so be patient please.
    ```
    # ./apply-rg.sh
    ```
7. From now on, you can create and reset the Kubernetes cluster as often as you want
     ```
    # ./deploy.sh
    ```
    When you want to start from scratch (but without destroying the Azure resources), call ./reset.sh
    ```
    # ./reset.sh
    ```
8. To completely delete all Azure resources from the resource group, simply call ./clear-rg.sh
    ```
    # ./clear-rg.sh
    ```

## Kubernetes 1.5 and local Kubernetes build 
At the time of the initial version of this project, Kubernetes 1.5. was not released yet. But as latest Azure fixes and features (e.g. Dynamic Disk Provisioning) and kubeadm features+fixes were only merged into the current master branch, I had to use a custom built version of Kubernetes.

Currently the Ansible project will install the latest RPMs found in the official Kubernetes repos, and then overwrite the binaries with a custom built version of Kubernetes. This custom built version is expected to be located relative to the Ansible project in "../kubernetes". This means that you'll have to place the latest Kubernetes master at this location and then build it either with "make" (requires a working Golang environment) or "make release-skip-tests" (Does not require a working Golang environment).
   
Additionally, you'll need to build and push the hyperkube Docker image after building Kubernetes. When you're inside the Kubernetes tree, you can do it this way:
```
# cd cluster/images/hyperkube
# make build REGISTRY=<myregistry> VERSION=<myversion>
# docker push <myregistry>/hyperkube-amd64:<myversion>
```
After pushing the image, you'll have to modify the Ansible variable "hyperkube_image" in group_vars/all to match you custom built and pushed image.

## Azure cloud provider support
The Azure cloud provider as found in 1.5. (as of writing, not released yet) is fully supported and configured. This includes Persistent Volumes, Dynamic Disk Provisioning and Azure Load Balancers. It also includes networking based on Azure route tables, which means that you do NOT have to install Weave or any other network addon.

## Addons
The Ansible role "addons" installs some common addons that I thought may be useful. The manifests found in the template directory are copied from the Kubernetes repository.
1. cluster-monitoring
2. dashboard
3. fluentd-elasticsearch
4. weave-net (currently disabled as we don't need it thanks to the Azure cloud provider)
5. weave-scope (currelty disable due to the overhead)

I plan to make addon installation more flexible and configurable.

## Bastion host
I chose to not assign public IPs to any of the masters or nodes as I want the cluster only to be accessible through Azure Load Balancers. Ansible however needs to establish SSH connections to all the hosts it wants to provision, thus a Bastion Host is introduced which is the only host with a public IP. The Ansible Role "bastion-ssh-conf" generates a SSH config which is then used for all connections. If you want to learn more about bastion hosts, please read http://blog.scottlowe.org/2015/12/24/running-ansible-through-ssh-bastion-host/
### Accessing the masters and nodes with ssh
As you can not directly SSH into the masters and nodes, you'll have to use the same basion SSH config as Ansible does. To access the master for example, call:
```
# ssh -A -F ssh-bastion.conf devops@10.0.4.4
```
The flag "-A" can be useful if you want to ssh into another node while you are already on the master for example.
## Cluster scaling
Cluster scaling is currently not implemented. You could of course change the minionsCount variable in roles/azure-template-generate/defaults/main.yml and re-run ./apply-rg.sh and ./deploy.sh, but I'm not a big fan of this. Especially when it comes to downscaling, I really don't like the idea that I'd have no control about which node gets removed. My long term goal is to implement roles and scripts to add and remove groups of nodes to/from the cluster.

## High Availability
High Availability (HA) is currently not implemented. Even if you change the mastersCount variable, it won't make your cluster HA. The problem currently is, that "kubeadm" does not support HA at the moment and thus I'm waiting for support of it. I may choose to implement a solution/hack which gives HA by simply copying the master configuration after the initial "kubeadm init", but I'm not a big fan of this...but it would serve the purpose until an integrated solution in kubeadm arrives.

## Limitations and hacks

### kubeadm flags for kubelet, apiserver and controller-manager
Currently it is not possible to pass custom flags to the kubelet, apiserver and controller-manager. There are multiple open issues in the Kubernetes repo and hopefully this gets adressed soon. Until then, I use a custom solution which injects the needed flags into the services.
1. For the kubelet, I add a systemd dropin with custom flags. These flags are mainly used to correctly pass the cloud provider to the kubelet and to setup networking modes compatible with the Azure cloud provider.
2. For the apiserver and controller-manager, I inject custom flags into their manifests directly after "kubeadm init" generates them. This solution relies on the kubelet to immediately restart/recreate the PODs of the apiserver and controller-manager.    

### ssl in hyperkube
Currently, kubeadm does not correctly host mount certificates into the apiserver and controller-manager, resulting in errors when the cloud provider tries to communicate with the Azure Rest APIs. https://github.com/kubernetes/kubernetes/issues/36150 describes this issue.
Until this is fixed in kubeadm, the "kubeadm-init" role removes the host mounts from the apiserver and controller-manager manifests.

### Azure availability sets
Currently, splitting up the masters and nodes into different availability sets is not supported as it makes the Azure cloud provider fail to add proper working load balancers.
It was suggested in https://github.com/colemickens/azure-kubernetes-status/issues/11 to make the masters have the --register-schedulabe=false set, but this is not compatible to kubeadm as it requires a fully working cluster with at least one node (the master itself) to finish the setup. 