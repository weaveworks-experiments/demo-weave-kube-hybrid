#!/usr/bin/python
print "finding kubeconfigs"
import os, yaml, subprocess
# short names for the clouds
contexts = dict(
    CLOUD_LONDON_DIGITALOCEAN="london",
    CLOUD_AMERICA_GCE="america",
    CLOUD_FRANKFURT_AWS="frankfurt",
)
# template for desired kubeconfig output
output = {
    "kind": "Config",
    "apiVersion": "v1",
    "current-context": contexts.values()[-1],
    "clusters": [],
    "users": [],
    "contexts": [],
}
API_PORT = 443 # change this when upgrading to -unstable kubeadm
for f in os.listdir("."):
    if f.startswith("CLOUD_"):
        kubeconfig = yaml.load(open(f+"/kubeconfig"))
        context_name = contexts[f] # ie london, frankfurt, america
        print f
        print str(kubeconfig)[:10], "..."
        master_ip = subprocess.check_output("cd %s; terraform output master_ip" % (f,), shell=True).strip()
        print master_ip
        # clusters
        cluster = kubeconfig["clusters"][0].copy()
        cluster["cluster"]["server"] = "https://%s:%d" % (master_ip, API_PORT)
        cluster["cluster"]["insecure-skip-tls-verify"] = True
        cluster["name"] = context_name
        output["clusters"].append(cluster)
        # users
        user = kubeconfig["users"][0].copy()
        assert user["name"] == "admin", "unexpected username %s, expected admin" % (user["name"],)
        user["name"] = "admin-%s" % (context_name,)
        output["users"].append(user)
        # contexts
        context = dict(context=dict(cluster=context_name, user="admin-%s" % (context_name,)), name=context_name)
        output["contexts"].append(context)
f = open("kubeconfig", "w")
f.write(yaml.dump(output))
f.close()
print "Tada! Written output to kubeconfig. You may wish to:\n    cp kubeconfig ~/.kube/config"
