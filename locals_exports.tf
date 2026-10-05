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

# The cluster's exports (schema captf.io/oci-cluster/v1, README "Exports"):
# captf_cluster_outputs, or external_cluster_exports when the TerraformCluster
# is externally managed and the controller passes {} (CONVENTIONS.md
# section 12). Every read is try()-guarded so a missing value reaches the
# precondition on pool_instance_configuration.tf instead of failing an
# expression first.
locals {
  externally_managed = try(length(var.captf_cluster_outputs), 0) == 0
  # Tuple index, not a conditional: a conditional would try to unify {} with
  # the exports object and fail on its mixed attribute types.
  exports = [var.captf_cluster_outputs, var.external_cluster_exports][local.externally_managed ? 1 : 0]

  region         = try(local.exports.region, null)
  compartment_id = try(local.exports.compartment_id, null)
  # Pools are workers: control-plane nodes are Machines (KCP, RKE2ControlPlane).
  node_subnet_id          = try(local.exports.worker_subnet_id, null)
  node_nsg_id             = try(local.exports.worker_nsg_id, null)
  node_defined_tags       = try(local.exports.node_defined_tags, {})
  cluster_failure_domains = try(local.exports.failure_domains, {})
}
