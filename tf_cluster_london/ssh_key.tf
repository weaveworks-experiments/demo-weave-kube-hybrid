resource "digitalocean_ssh_key" "default" {
    name = "Terraform k8s-test SSH key (github.com/weaveworks/weave-kube-hybrid-cloud)"
    public_key = "${var.k8s_ssh_key}"
}
