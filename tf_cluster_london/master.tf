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
data "template_file" "master-userdata" {
    template = "${file("${var.master-userdata}")}"

    vars {
        k8stoken = "${var.k8s_token}"
    }
}

////////////////////////////////////////////////////////////////////////////////
// VMs

resource "digitalocean_droplet" "master" {
  image          = "ubuntu-16-04-x64"
  name           = "${var.cluster-name-base}-master"
  size           = "${var.master_machine_type}"
  region         = "${var.do_region}"
  ssh_keys       = ["${digitalocean_ssh_key.default.id}"]
  user_data      = "${data.template_file.master-userdata.rendered}"
}
