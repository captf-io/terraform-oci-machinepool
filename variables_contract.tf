# Copyright 2026 The CAPTF Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Contract inputs of the machinepool role, in contract order and with the
# contract's types: https://captf.io/docs/module-author/contract/v1alpha1/common.html
# and https://captf.io/docs/module-author/contract/v1alpha1/machinepool.html.

# Read only by its own validation, which is the point of it.
# tflint-ignore: terraform_unused_declarations
variable "captf_contract" {
  description = "Contract version the controller generated the root module for. Always \"v1alpha1\"."
  type        = string

  validation {
    condition     = var.captf_contract == "v1alpha1"
    error_message = "captf_contract must be \"v1alpha1\": this module implements contract v1alpha1 only."
  }
}

variable "captf_cluster" {
  description = "The owning CAPI Cluster: name and namespace. Pool resource names derive from it and machinepool_name."
  type = object({
    name      = string
    namespace = string
  })
}

# Names derive from the Cluster and the MachinePool (machinepool_name); the
# TerraformMachinePool adds nothing to them.
# tflint-ignore: terraform_unused_declarations
variable "captf_object" {
  description = "The TerraformMachinePool being reconciled: kind, name and namespace."
  type = object({
    kind      = string
    name      = string
    namespace = string
  })
}

variable "captf_cluster_outputs" {
  description = "The cluster role's exports (schema captf.io/oci-cluster/v1), or {} for an externally managed TerraformCluster (then external_cluster_exports applies)."
  type        = any

  validation {
    condition     = try(length(var.captf_cluster_outputs), 0) == 0 || try(var.captf_cluster_outputs.schema, null) == "captf.io/oci-cluster/v1"
    error_message = "captf_cluster_outputs must be the exports of the OCI cluster module (schema captf.io/oci-cluster/v1): the TerraformCluster runs a different or incompatible cluster module."
  }
}

variable "captf_tags" {
  description = "Fixed tags the controller sets (captf.io/cluster, namespace, kind, name, managed-by, template). Applied to every taggable resource as OCI free-form tags."
  type        = map(string)
}

variable "machinepool_name" {
  description = "Name of the owning CAPI MachinePool. Part of every pool resource name."
  type        = string
}

variable "replicas" {
  description = "Desired instance count: MachinePool.spec.replicas, or with autoscaling the observed count clamped into [min, max]. The pool's size at creation; with autoscaling the autoscaler owns it afterwards."
  type        = number

  validation {
    condition     = var.replicas >= 0 && floor(var.replicas) == var.replicas
    error_message = "replicas must be a whole number of at least 0."
  }
}

variable "bootstrap_data" {
  description = "Base64 of the bootstrap Secret's value. Without node labels it is the instances' user_data unchanged; with them, the second part of a MIME multipart."
  type        = string
  sensitive   = true
}

variable "bootstrap_format" {
  description = "Format of the bootstrap payload: cloud-config or ignition. Node labels need cloud-config."
  type        = string

  validation {
    condition     = contains(["cloud-config", "ignition"], var.bootstrap_format)
    error_message = "bootstrap_format must be cloud-config or ignition."
  }
}

variable "failure_domains" {
  description = "MachinePool.spec.failureDomains: failure domain names from the cluster's exports. [] spreads over cluster_failure_domains."
  type        = list(string)
}

variable "cluster_failure_domains" {
  description = "The cluster's failure domain names, read from its state. [] falls back to every failure domain in the exports."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "MachinePool.spec.template.spec.version. A change replaces the pool (a roll); image_id must carry the new version."
  type        = string
  default     = null
}

variable "node_labels" {
  description = "MachinePool.spec.template.metadata.labels, registered by the kubelet (--node-labels) and the RKE2 agent through a boothook part. Labels the NodeRestriction admission plugin forbids are dropped."
  type        = map(string)
}

variable "autoscaling" {
  description = "Parsed from the MachinePool's autoscaler annotations. enabled hands the size to a scaler within these bounds: this module's OCI autoscaling configuration, or one outside it, as the autoscaler variable says."
  type = object({
    enabled = bool
    min     = number
    max     = number
  })
}
