// Copyright 2016 Joe Beda. Modified by Luke Marsden
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
data "template_file" "prereq-master" {
  template = "${file("../scripts/prereq.sh")}"
}

// This script will install Kubernetes on the master.
data "template_file" "master" {
  template = "${file("../scripts/master.sh")}"

  vars {
    token        = "${var.k8s_token}"
  }
}

// Package all of this up in to one base64 encoded string so that cloud init in
// the VM can run these scripts once booted.
data "template_cloudinit_config" "master" {
  base64_encode = true
  gzip          = true

  part {
    filename     = "../scripts/per-instance/10-prereq.sh"
    content_type = "text/x-shellscript"
    content      = "${data.template_file.prereq-master.rendered}"
  }

  part {
    filename     = "../scripts/per-instance/20-master.sh"
    content_type = "text/x-shellscript"
    content      = "${data.template_file.master.rendered}"
  }
}

////////////////////////////////////////////////////////////////////////////////
// VMs

resource "digitalocean_droplet" "master" {
  image          = "ubuntu-16-04-x64"
  name           = "${var.cluster-name-base}-master"
  size           = "${var.master_machine_type}"
  region         = "${var.do_region}"
}
