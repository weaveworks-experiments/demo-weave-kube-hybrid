# Weave + Kubernetes Federation across cloud providers

Simple demo of hybrid cloud federation with Weave Net and Kubernetes.

We'll spin up a federated cluster across DigitalOcean in London, AWS in Frankfurt and GCE in America.

## Steps

### (1/5) Prepare

Collect cloud credentials and insert them in `secrets`.

```
$ ssh-keygen -f k8s-test
$ cp secrets.template secrets && $EDITOR secrets
```

Do GCE-specific setup:
```
$ source ./secrets && \
   (cd CLOUD_AMERICA_GCE && terraform get && \
    gcloud config set project $TF_VAR_gce_project && \
    SA_EMAIL=$(gcloud iam service-accounts --format='value(email)' create k8s-terraform)
    gcloud iam service-accounts keys create account.json --iam-account=$SA_EMAIL)
```

### (2/5) Use terraform to create some clusters

In three terminal windows:

```
$ source ./secrets && cd CLOUD_LONDON_DIGITALOCEAN && terraform apply
$ source ./secrets && cd CLOUD_FRANKFURT_AWS && terraform apply
$ source ./secrets && cd CLOUD_AMERICA_GCE && terraform apply
```

This should spit out IP addresses in `terraform output` for `master` and `nodes`.

Get the kubeconfig files out:

```
$ for X in CLOUD_*; do
    cd $X && \
    ssh -i ../k8s-test ubuntu@$(terraform output master_ip) sudo cat /etc/kubernetes/admin.conf > kubeconfig && \
    cd ..
  done
$ kubectl mumble mumble contexts (london, frankfurt, america)
```

### (3/5) Set up Weave network spanning all clouds

The Weave routers will join up into a resilient hybrid cloud mesh network, given just a single meeting point IP.

```
cat weave-kube-init.yaml | sed s/PASSWORD/$WEAVE_PASSWORD \
    | kubectl --context=london apply -f weave-kube-init.yaml
export MEETING_POINT=$(cd CLOUD_LONDON_DIGITALOCEAN && terraform output master-ip)
for location in frankfurt america; do
    cat weave-kube-join.yaml |sed s/MEETING_POINT/$MEETING_POINT/ \
        | sed s/PASSWORD/$WEAVE_PASSWORD \
        | kubectl --context=$location apply -f -
done
```

### (4/5) Set up control plane

TODO

Spin up control plane on DO.
Don't bother with PVs for now.

Upload kubeconfigs of FRANKFURT and AMERICA to LONDON as secrets.

```
$ kubectl mumble mumble federation namespace
```

### (5/5) Deploy app

TODO

Deploy socks shop to federation apiserver, tweaked to show where it's being served from.

Stateless components & caches can go everywhere.
Only stateful components (ie basket) need to do high-latency hop.

Can all components register in DNS using their Weave IPs??
So that front-end in one cloud can securely talk to orders-service in another, for example?

Aronchick wanted to show a rolling upgrade, can we do that with flux?


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
