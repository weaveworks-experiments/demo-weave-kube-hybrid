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

data "template_file" "worker-userdata" {
    template = "${file("${var.worker-userdata}")}"

    vars {
        k8stoken = "${var.k8s_token}"
        masterIP = "${digitalocean_droplet.master.ipv4_address}"
    }
}

////////////////////////////////////////////////////////////////////////////////
// VMs

resource "digitalocean_droplet" "node" {
  count          = "${var.num-nodes}"
  image          = "ubuntu-16-04-x64"
  name           = "${var.cluster-name-base}-node-${count.index}"
  size           = "${var.master_machine_type}"
  region         = "${var.do_region}"
  ssh_keys       = ["${digitalocean_ssh_key.default.id}"]
  user_data      = "${element(data.template_file.worker-userdata.*.rendered, count.index)}"
}
