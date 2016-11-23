# kubernetes-ansible-azure

## What it is this?
The target of this project is to deploy and maintain a [Kubernetes Cluster](http://kubernetes.io/) on [Azure](https://azure.microsoft.com/de-de/), using [CentOS7.2](https://www.centos.org/) as the Operating System and [Ansible](https://www.ansible.com/) & [kubeadm]((http://kubernetes.io/docs/admin/kubeadm/)) for deployment tasks.

## Why not use any of the existing solutions?
Also, we prefer a solution where we have full overview and control about what happens. We want to see the logs while stuff is installed and initialized. This means that solutions which put responsibility for all this onto the VM (like only deploying a script which then downloads, installs and configures everything) were not viable candidates. 

Setting up and running our Kubernetes cluster has proofed too often that things could go wrong and that debugging and intervention isthen required. We beleive its a lot simpler when [Ansible](https://www.ansible.com/) is used.

[kubeadm](http://kubernetes.io/docs/admin/kubeadm/) seems to become the standard in cluster deployment. It makes deployment a lot easier, especially when it comes to certificate management.

Also, we prefer a solution were we have full overview and control about what happens. We should be able to see logs while stuff is installed and initialized. This means that solutions which put responsibility for all this onto the VM (like only deploying a script which then downloads, installs and configures everything) were not viable candidates for us.

Setting up and running a Kubernetes cluster has shown too often that things can go wrong and that debugging and intervention is required, something that is a lot simpler when Ansible is used.

## Getting started
Setting up a Kubernetes cluster with a Ansible project consists of multiple steps. The following text outlines the steps necesarry

1. Create an Azure Resource Group inside of your Azure subscription. Please read through the Azure docs or contact your Azure administrator for this.
2. Add a *Azure Service Principal Account* and appropriate credentials for the SP. Please read through related [*Azure documentation*](https://azure.microsoft.com/en-us/documentation/articles/resource-group-create-service-principal-portal/) for the details. The SP is used to setup the Azure resources with Azure Resource Templates and is also later used by the Kubernetes Cloud Provider to modify resources as needed. It includes e.g. Routing Table entries, Load Balancers, ...
3.  Generate a backup of *azure_creds.env.example*, rename it to *azure_creds.env* and update the file with your SP credentials. Additionally add the [*resource group name*](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-overview) and [*resource location*](https://docs.microsoft.com/en-gb/azure/azure-resource-manager/resource-group-move-resources).
4. Edit [*group_vars/all*](http://docs.ansible.com/ansible/playbooks_variables.html) to include your custom admin password and your own ssh public key. Please also make sure the private key is known to the SSH Agent. That probably might be automated at a later stage. You also have to choose a globally unique cluster name in *cluster_name*
5. Before executing anything from this Ansible project, you'll have to source in the Azure credentials:

    ```
    $ source ./azure_creds.env
    ```
6. To generate the [Azure Resource Templates](https://github.com/Azure/azure-quickstart-templates) and apply them to your Resource Group, call "./apply-rg.sh". This will take quite some time, so be patient please.

    ```
    $ ./apply-rg.sh
    ```
7. From now on, you can create and reset the Kubernetes cluster as often as you want

     ```
    $ ./deploy.sh
    ```
    When you want to start from scratch (but without destroying the Azure resources), call ./reset.sh
    
    ```
    $ ./reset.sh
    ```
8. To completely delete all Azure resources from the resource group, simply call ./clear-rg.sh

    ```
    $ ./clear-rg.sh
    ```

## Accessing the API and UI after the cluster is running
An Azure Load Balancer is set up to accept API connections and can be reached through the domain: 

    <cluster_name>-api.<resource_location>.cloudapp.azure.com
     
As anonymous auth is disabled, you can not directly access the UI. You'll have to use the kubectl proxy to access the UI (and other services) with a valid kubectl config. The deploy playbook (and thus ./deploy.sh) will copy/create this config in

    ./kubeconfigs/<cluster_name>/admin.conf. 
    
You should set the KUBECONFIG environment variable to use this config:
```
$ export KUBECONFIG=$(pwd)/kubeconfigs/<cluster_name>/admin.conf
```
An example export command line is printed at the end of ./deploy.sh execution. You can now use kubectl as you are used to. To start the kubectl proxy, call:
```
$ kubectl proxy
Starting to serve on 127.0.0.1:8001
```
You can now access the cluster addons though these URLs:
 
* [Local Kubernetes Dashboard](http://localhost:8001/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard)
* [Local Kibana Logging](http://localhost:8001/api/v1/proxy/namespaces/kube-system/services/kibana-logging)
* [Local Grafana Monitoring](http://localhost:8001/api/v1/proxy/namespaces/kube-system/services/monitoring-grafana)

Please not that it may take some time until all addons are ready after cluster startup. There are a lot of container images which need to be fetched ...

## Kubernetes 1.5 and a local Kubernetes build 
At the time of the initial version of this project, Kubernetes 1.5. was not released yet. But as latest Azure fixes and features (e.g. Dynamic Disk Provisioning) and kubeadm features+fixes were only merged into the current master branch, We had to use a custom built version of Kubernetes.

Currently the Ansible project will install the latest RPMs found in the official Kubernetes repos, and then overwrite the binaries with a custom built version of Kubernetes. This custom built version is expected to be located relative to the Ansible project in "../kubernetes". This means that you'll have to place the latest Kubernetes master at this location and then build it either with "make" (requires a working Golang environment) or "make release-skip-tests" (Does not require a working Golang environment).
   
Additionally, you'll need to build and push the hyperkube Docker image after building Kubernetes. When you're inside the Kubernetes tree, you can do it this way:
```
$ cd cluster/images/hyperkube
$ make build REGISTRY=<myregistry> VERSION=<myversion>
$ docker push <myregistry>/hyperkube-amd64:<myversion>
```
After pushing the image, you'll have to modify the Ansible variable "hyperkube_image" in group_vars/all to match you custom built and pushed image.

## Azure Cloud Provider Support
The Azure cloud provider as found in 1.5. (as of writing, not released yet) is fully supported and configured. This includes Persistent Volumes, Dynamic Disk Provisioning and Azure Load Balancers. It also includes networking based on Azure route tables, which means that you do NOT have to install Weave or any other network addon.

## Addon's
The Ansible role "addons" installs some common addons that I thought may be useful. A role is the Ansible way of bundling automation content and making it reusable. The manifests found in the template directory are copied from the Kubernetes repository.

1. Cluster-monitoring
2. Dashboard
3. Fluentd-elasticsearch
4. Weave-net (currently disabled as we don't need it thanks to the Azure cloud provider)
5. Weave-scope (currently disabled due to the overhead)
6. Registry
7. Traefik-ingress-controller

Its planed to make the addon installation more flexible and configurable.

## Accesing the Registry
A docker registry is deployed into the cluster which can be accessed from inside the cluster through

    "localhost:5000/<namespace>/<image>:<tag>" 

Internally, a registry-proxy is deployed as a DaemonSet to make the registry available on every node on port 5000.

To access the registry from outside of the cluster, you'll have to set up port forwarding with kubectl:

```console
$ POD=$(kubectl get pods --namespace kube-system -l k8s-app=kube-registry \
    -o template --template '{{range .items}}{{.metadata.name}} {{.status.phase}}{{"\n"}}{{end}}' \
    | grep Running | head -1 | cut -f1 -d' ')

$ kubectl port-forward --namespace kube-system $POD 5000:5000 &
```

As an alternative, use 

     ./registry-local-access.sh
which does all this for you.

Now the registry is also accessible from your local machine.

## Bastion Host
I chose to not assign public IPs to any of the masters or nodes as I want the cluster only to be accessible through Azure Load Balancers. Ansible however needs to establish SSH connections to all the hosts it wants to provision, thus a Bastion Host is introduced which is the only host with a public IP. The Ansible Role "bastion-ssh-conf" generates a SSH config which is then used for all connections. If you want to learn more about bastion hosts, please read "[Running Ansible Through an SSH Bastion Host](http://blog.scottlowe.org/2015/12/24/running-ansible-through-ssh-bastion-host/)"

### Accessing the Masters and Nodes with SSH
As you can not directly SSH into the masters and nodes, you'll have to use the same basion SSH config as Ansible does. To access the master for example, call:
```
$ ssh -A -F ssh-bastion.conf devops@10.0.4.4
```
The flag "-A" can be useful if you want to ssh into another node while you are already on the master for example.

## Limitations and Hacks

## Cluster Scaling
Cluster scaling is currently not implemented. You could of course change the minionsCount variable in roles/azure-template-generate/defaults/main.yml and re-run 

    ./apply-rg.sh and ./deploy.sh

but its not recomended. Especially when it comes to downscaling. Personally I don't like the idea that I'd have no control about which node gets removed. Our long term goal is to implement roles and scripts to add and remove groups of nodes to/from the cluster.

## High Availability
High Availability (HA) is currently not implemented. 

Even if you change the *mastersCount* variable, it won't make your cluster HA. The problem currently is, that "kubeadm" does not support HA at the moment and thus I'm waiting for support of it. We might come up with a solution/hack which gives HA by simply copying the master configuration after the initial "kubeadm init", but again its not the recomended way ... but it would serve the purpose until an integrated solution in kubeadm arrives.

### kubeadm flags for kubelet, apiserver and controller-manager
Currently it is not possible to pass custom flags to the 
* kubelet, 
* apiserver and 
* controller-manager. 

There are multiple open issues in the Kubernetes repo and hopefully these will be adressed soon. Until then, we use a custom solution which injects the needed flags into the services.

1. For the *kubelet*, add a *systemd* dropin with custom flags. These flags are mainly used to correctly pass the cloud provider to the kubelet and to setup networking modes compatible with the Azure cloud provider.
2. For the *apiserver* and *controller-manager*, inject custom flags into their manifests directly after "kubeadm init" generates them. This solution relies on the kubelet to immediately restart/recreate the PODs of the apiserver and controller-manager.    

### SSL in [Hyperkube](https://github.com/kubernetes/kubernetes/blob/master/cluster/images/hyperkube/README.md)
Currently, kubeadm does not correctly host mount certificates into the *apiserver* and *controller-manager*, resulting in errors when the cloud provider tries to communicate with the Azure Rest APIs. [Issue 36150](https://github.com/kubernetes/kubernetes/issues/36150) describes this in detail.

Until this is fixed in *kubeadm*, the *kubeadm-init* role removes the host mounts from the *apiserver* and *controller-manager* manifests.
