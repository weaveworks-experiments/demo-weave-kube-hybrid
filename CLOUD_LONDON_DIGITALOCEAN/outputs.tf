output "master_ip" {
  value = "${digitalocean_droplet.master.ipv4_address}"
}
