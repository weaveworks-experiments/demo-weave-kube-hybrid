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

variable "cluster-name-base" {
  default = "kube"
}

variable "do_token" {
  default = "lon1"
}

variable "do_region" {
  default = "lon1"
}

variable "master_machine_type" {
  default = "2gb"
}

variable "node_machine_type" {
  default = "2gb"
}

variable "k8s_token" {
  default = ""
}

variable "num-nodes" {
  default = 3
}

variable "k8s_ssh_key" {}

variable "master-userdata" {
    default = "../scripts/master-combined.sh"
}

variable "worker-userdata" {
    default = "../scripts/node-combined.sh"
}
