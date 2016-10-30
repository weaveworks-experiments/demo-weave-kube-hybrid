# Weave + Kubernetes Federation across cloud providers

Simple demo of hybrid cloud federation with Weave Net and Kubernetes.

## Steps

### (0/3) Prepare

Collect cloud credentials and insert them in `secrets`.

```
$ cp secrets.template secrets && $EDITOR secrets
```

### (1/3) Use terraform to create some machines

In three terminal windows:

```
$ cd CLOUD_LONDON_DIGITALOCEAN && source ../secrets && terraform apply
$ cd CLOUD_FRANKFURT_AWS && source ../secrets && terraform apply
$ cd CLOUD_AMERICA_GCE && source ../secrets && terraform apply
```

This should spit out IP addresses in `terraform output` for `master` and `nodes`.

Get the kubeconfig files out:

```
$ for X in CLOUD_*; do
    cd $X && scp root@`terraform output master`:/etc/kubernetes/admin.conf . && cd ..
  done
```

### (2/3) Set up control plane

Spin up control plane on DO.
Don't bother with PV for now.

Upload kubeconfigs as secrets.


### (3/4) Deploy app

Deploy socks shop, tweaked to show where it's being served from.

Stateless components & caches can go everywhere.
Only stateful components (ie basket) need to do high-latency hop.

Can all components register in DNS using their Weave IPs??


## Notes

See also 'Transforming Infrastructure with Containers & Kubernetes' slides.

* Slide 32 (setting up kubeadm & overlay network)
    * Here's how easy it is to set up a master
    * Here's how easy it is to add a node
    * And a second node
    * and 15 more nodes - for i in `seq 1 15`; do; ssh node-$i "kubeadm join --token <foo> --master=10.10.19.13" ; done;
    * Deploy weave net
* Slide 43-65
    * Log into a cluster (GKE)
    * Create a federation
    * Log into second cluster (AWS)
    * Join federation
    * Deploy an app across all clusters
    * Deploy a service across all clusters
    * kubectl get pods - show in all clusters
    * <new window> while true; curl http://federated-ingress-endpoint/gimme-your-ip; end
    * Show IPs going across clusters
    * Deploy rolling update across clusters
    * Show curl starting to update across all clusters
* Slide 67
    * Install helm
    * Show text for chart
    * Install app (mariadb? mysql?)
    * Maybe that's it?
