# Inception-of-Things
This project is an introduction to using kubernetes.

## Usage
Clone repository. 

Run ./vm.sh create to create the machine. 

Then run ./vm.sh console or ./vm.sh ssh to connect to the virtual machine. Note that to connect with ssh you have to wait until the key is generated which takes some time after running vm create.

## Pre-work
What is k8s?
An open source system for automating deployment, scaling, and management of containerized applications.

What is k3s?
Lightweight k8s distribution for IoT & Edge computing.

What is kubectl?
kubectl is a command line tool for communicating with Kubernetes.

What is vagrant?
Command line utility for managing the lifecycle of virtual machines.

What is k3d?
A lightweight wrapper to run k3s in docker.

What is Argo CD?
A declarative, GitOps continuous delivery tool for Kubernetes.

### Setting up the environment
We decided to use cloud-init to be able to easily deploy our host machine with our preferred configuration anywhere, and specially as a more lightweight than other virtual machine providers with GUIs.

### Monitoring and testing
The 3 parts to this project are:
- K3s and Vagrant
- K3s and three simple applications
- K3d and Argo CD

In part one we want to monitor:
- vm health (CPU, memory, disk)
- k3s is running in each vm
- k3s nodes status
- Connectivity between nodes

## Part one
Set up 2 virtual machines with vagrant and install k3s in them.

### Requirements
- [x] Specific machine names.
- [x] Dedicated IP on the primary network interface.
- [x] Be able to connect with SSH on both machines with no password.
- [x] k3s installed in controller mode in machine one.
- [x] k3s installed in agent mode in machine two.
- [ ] Nodes can communicate between them

### How to write a Vagrantfile according to modern practices

### K3s installation
k3s installation was made easy by just using the script provided by k3s and we didn't encounter any issues.

## Optimization
We are very limited in our work and production environment therefore optimization is a real worry.

Our first working vagrantfile when doing vagrant up took:
real	5m55.826s
user	0m12.701s
sys	0m6.660s

Memory leftover was terrible:
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       2.5Gi       129Mi       1.5Mi       1.4Gi       1.3Gi
Memory with the clusters removed with vagrant destroy:
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       490Mi       3.1Gi       1.1Mi       428Mi       3.3Gi
Swap:             0B          0B          0B

