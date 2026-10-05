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

# Contract outputs of the machinepool role, in contract order:
# https://captf.io/docs/module-author/contract/v1alpha1/machinepool.html#outputs
# and common.md "Outputs" (health).

output "provider_id" {
  description = "OCID of the instance pool, the scaling group. It changes when a Kubernetes version change replaces the pool."
  value       = local.pool_id
}

output "provider_id_list" {
  description = "oci://<instance OCID> of every member that is not terminated, whatever its health: the OCI cloud controller manager's Node.spec.providerID format (see machine/README.md)."
  value       = sort([for m in local.members : "oci://${m.id}"])
}

output "replicas" {
  description = "The pool's desired size as OCI reports it (actual_size): replicas, or what the autoscaler decided."
  value       = local.desired_size
}

output "instances" {
  description = "Every member: provider ID, instance OCID, failure domain and health state. The pool's instance list carries no addresses."
  value = [for m in local.members : {
    provider_id    = "oci://${m.id}"
    instance_id    = m.id
    addresses      = []
    failure_domain = lookup(local.failure_domain_by_placement, "${m.availability_domain}/${m.fault_domain}", lookup(local.failure_domain_by_placement, m.availability_domain, null))
    state          = m.state
  }]
}

output "health" {
  description = "Pool health: running and healthy at zero replicas or when every member runs at the desired size; else the worst member state, with the affected instances in reasons (common.md \"Outputs\")."
  value = {
    state   = local.health_state
    healthy = local.health_healthy
    message = local.health_message
    reasons = local.health_reasons
  }
}
