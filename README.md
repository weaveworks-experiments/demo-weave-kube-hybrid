# Weave + Kubernetes Federation across cloud providers

Simple demo of hybrid cloud federation with Weave Net and Kubernetes.

We'll spin up a federated cluster across DigitalOcean in London, AWS in Frankfurt and GCE in America.

## Prerequisites

* [Terraform](https://terraform.io) 0.7.8+
* Python 2.7 with yaml module
* Bash
* Cloud provider credentials for GCE, AWS and DigitalOcean.

Tested on macOS, should also work on Linux.

## Steps

### (1/5) Prepare

Collect cloud credentials and insert them in `secrets`.

```shell
ssh-keygen -f k8s-test
cp secrets.template secrets && $EDITOR secrets
```

Do GCE-specific setup:
```shell
source ./secrets && ./tf_cluster_america/fetch_gce_secrets
```

Set up a Google DNS Managed Zone (you'll need your own domain for this bit).
```shell
gcloud dns managed-zones create federation \
    --description "Kubernetes federation testing" \
    --dns-name cluster.world
```

### (2/5) Use Terraform to create some clusters

In three terminal windows:

```shell
source ./secrets && (cd tf_cluster_london && terraform apply)
source ./secrets && (cd tf_cluster_frankfurt && terraform apply)
source ./secrets && (cd tf_cluster_america && terraform apply)
```

This should spit out IP addresses in `terraform output` for `master_ip`.

Wait a while for the clusters to come up.

**You'll only need one terminal window for the rest of these instructions.**

Get the kubeconfig files out:

```shell
for X in london frankfurt america; do
    ./ssh_master ${X} sudo cat /etc/kubernetes/admin.conf > tf_cluster_${X}/kubeconfig
done
```

Run the bundled `munge_configs.py` program to merge the kubeconfigs into one with multiple contexts:
```shell
python munge_configs.py && cp kubeconfig ~/.kube/config
```

You should now be able to enumerate your clusters:
```shell
kubectl config get-contexts
```

And list nodes in them:
```shell
kubectl --context=london get nodes
kubectl --context=frankfurt get nodes
kubectl --context=america get nodes
```

### (3/5) Set up Weave network spanning all clouds

The Weave routers will join up into a resilient hybrid cloud mesh network, given just a single meeting point IP.

Set up the network on the federated control plane cluster (america) first:
```shell
source ./secrets
cat weave-kube-init.yaml | sed s/WEAVE_PASSWORD/$WEAVE_SECRET/ \
    | kubectl --context=america apply -f -
```
Remember the IP of the master there. Note that this is only used for bootstrapping, once the Weave network has come up this will stop being a single point of failure.
```shell
export MEETING_POINT=$(cd tf_cluster_america && terraform output master_ip)
```

Then join the other two locations up to the first cluster:
```shell
source ./secrets
for X in london frankfurt; do
    cat weave-kube-join.yaml |sed s/MEETING_POINT/$MEETING_POINT/ \
        | sed s/WEAVE_PASSWORD/$WEAVE_SECRET/ \
        | kubectl --context=${X} apply -f -
done
```

To check that the network came up across 3 clouds, first install the weave script on the hosts, for easy
status-checking:
```shell
for X in london frankfurt america; do
    ./ssh_master ${X} "sudo curl -s -L git.io/weave -o /usr/local/bin/weave && sudo chmod +x /usr/local/bin/weave"
done
```

Then run status:
```shell
for X in london frankfurt america; do
    ./ssh_master ${X} sudo weave status
done
```

### (4/5) Set up control plane

The Kubernetes federation control plane will run in the federation namespace. Create the federation namespace using kubectl:
```
kubectl --context=america create namespace federation
```

Configure a token for the federated API server:
```
echo "$(python -c \
        'import random; print "%0x" % (random.SystemRandom().getrandbits(16*8),)' \
       ),admin,admin" > known-tokens.csv
```

Save `known-tokens.csv` in Kubernetes secret in federated control plane:

```
kubectl --context=america --namespace=federation \
    create secret generic federation-apiserver-secrets --from-file=known-tokens.csv
kubectl --context=america --namespace=federation \
    describe secrets federation-apiserver-secrets
```

The federated API server will use a NodePort on static port 30443 on all nodes in America with token auth.
Now deploy federated API service and federated API/controller-manager deployments:
```
$EDITOR config/deployments/federation-controller-manager.yaml
# Change 'cluster.world' to your own domain name that is under control of
# google cloud DNS.
kubectl --context=america apply -f config/services -f config/deployments
```

Remind ourselves of the token we created earlier:
```
FEDERATION_CLUSTER_TOKEN=$(cut -d"," -f1 known-tokens.csv)
```

Create a new kubectl context for it in our local kubeconfig (`~/.kube/config`):
```
kubectl config set-cluster federation-cluster \
    --server=https://$(cd tf_cluster_america; terraform output master_ip):30443 \
    --insecure-skip-tls-verify=true
kubectl config set-credentials federation-cluster \
    --token=${FEDERATION_CLUSTER_TOKEN}
kubectl config set-context federation-cluster \
    --cluster=federation-cluster \
    --user=federation-cluster
kubectl config use-context federation-cluster
mkdir -p kubeconfigs/federation-apiserver
kubectl config view --flatten --minify > kubeconfigs/federation-apiserver/kubeconfig
```

Create a secret for the federation control plane's kubeconfig:
```
kubectl --context="america" --namespace=federation \
    create secret generic federation-apiserver-kubeconfig \
    --from-file=kubeconfigs/federation-apiserver/kubeconfig
kubectl --context="america" \
    --namespace=federation \
    describe secrets federation-apiserver-kubeconfig
```

Wait for federation API server and controller manager to come up.
Check by running:
```
kubectl --context=america --namespace=federation get pods
```

Upload kubeconfigs of frankfurt and london to america as secrets.
```
for X in london frankfurt; do
    kubectl --context=america --namespace=federation create secret generic ${X} --from-file=kubeconfigs/${X}/kubeconfig
    kubectl --context=federation-cluster create -f config/clusters/${X}.yaml
done
```
To see when both clusters are ready, run:
```
kubectl --context=federation-cluster get clusters
```

### (5/5) Deploy a database with cross-datacenter replication

First, we are going to create PostgreSQL master and replicas. Master will run in london datacenter,
and replicas will run in both datacenters. We will use Weave Cloud to monitor connectivity
between master and the replicas.

Install Weave Scope agent with a token for [Weave Cloud](https://cloud.weave.works):
```shell
WEAVE_CLOUD_TOKEN=<insert_your_token_here>
for X in london frankfurt america; do
    kubectl --context=${X} --namespace=kube-system create -f \
        "http://frontend.dev.weave.works/k8s/scope.json?t=${WEAVE_CLOUD_TOKEN}"
done
```

Deploy PostgreSQL master
```shell
kubectl --context=federated-cluster create -f psql/master.yaml
```

Now wait for the pod to become ready:
```shell
kubectl --context=london get pods --selector name=psql-master
```

Get pod IP:
```shell
PSQL_MASTER_IP="$(kubectl --context=london get pods --selector name=psql-master --output=template --template='{{range .items}}{{.status.podIP}}{{end}}')"
```

Next, create replicas:
```shell
sed s/INSERT_MASTER_POD_IP/$PSQL_MASTER_IP/ psql/replica.yaml | kubectl --context=federated-cluster create -f -
```

If you take a look at `psql/replica.yaml`, you will see that we are told Kubernetes to run up to 4 replicas in cluster frankfurt
and up to 2 replicas in cluster london. We can confirm this by running `kubectl` agains each of the clusters like this:
```console
wroom:demo-weave-kube-hybrid ilya$ kubectl --context london get rs
NAME           DESIRED   CURRENT   READY     AGE
psql-master    1         1         1         11m
psql-replica   2         2         2         1m
wroom:demo-weave-kube-hybrid ilya$ kubectl --context frankfurt get rs
NAME           DESIRED   CURRENT   READY     AGE
psql-replica   4         4         4         1m
wroom:demo-weave-kube-hybrid ilya$ 
```

We can also see this in Weave Cloud graph view, as shown in the screenshot below.

![Screenshot of Weave Cloud](https://www.dropbox.com/s/z1bd2bik0s03eab/Screenshot%202016-11-03%2018.43.44.png?dl=1)

### Destroying everything

```shell
for X in london frankfurt america; do
    (cd tf_cluster_${X}; terraform destroy -force)
done
```
