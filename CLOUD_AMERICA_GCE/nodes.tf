// Copyright 2016 Joe Beda
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Start up scripts

// This script will install docker, the kubelet and configure networking on the
// node.
data "template_file" "prereq-node" {
  count    = "${var.num-nodes}"
  template = "${file("../scripts/prereq.sh")}"
}

// This script will have the node join the master.  It verifies itself with the
// token.
data "template_file" "node" {
  template = "${file("../scripts/node.sh")}"

  vars {
    token     = "${var.k8s_token}"
    master-ip = "${google_compute_instance.master.network_interface.0.address}"
  }
}

// Package all of this up in to one base64 encoded string so that cloud init in
// the VM can run these scripts once booted.
data "template_cloudinit_config" "node" {
  count         = "${var.num-nodes}"
  base64_encode = true
  gzip          = true

  part {
    filename     = "../scripts/per-instance/10-prereq.sh"
    content_type = "text/x-shellscript"
    content      = "${element(data.template_file.prereq-node.*.rendered, count.index)}"
  }

  part {
    filename     = "../scripts/per-instance/20-node.sh"
    content_type = "text/x-shellscript"
    content      = "${data.template_file.node.rendered}"
  }
}

////////////////////////////////////////////////////////////////////////////////
// VMs

resource "google_compute_instance" "node" {
  count          = "${var.num-nodes}"
  name           = "${var.cluster-name-base}-node-${count.index}"
  machine_type   = "${var.node_machine_type}"
  zone           = "${var.gce_zone}"

  // This allows this VM to send traffic from containers without NAT.  Without
  // this set GCE will verify that traffic from a VM only comes from an IP
  // assigned to that VM.
  can_ip_forward = true

  disk {
    image = "ubuntu-os-cloud/ubuntu-1604-lts"
    type  = "pd-ssd"
    size  = "200"
  }

  metadata {
    "user-data" = "${element(data.template_cloudinit_config.node.*.rendered, count.index)}"
    "user-data-encoding" = "base64"
    "ssh-keys" = "ubuntu:${var.k8s_ssh_key}"
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }
}
