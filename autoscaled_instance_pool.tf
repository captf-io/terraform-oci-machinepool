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

# The pool when autoscaling is on: created at replicas, then sized by
# pool_autoscaling_configuration.tf, so an apply never resets what the
# autoscaler decided (machinepool.md "autoscaling (input)"). See
# fixed_instance_pool.tf for why there are two pool resources.
resource "oci_core_instance_pool" "autoscaled_instance_pool" {
  count = var.autoscaling.enabled ? 1 : 0

  compartment_id            = local.compartment_id
  display_name              = local.name_prefix
  freeform_tags             = local.tags
  instance_configuration_id = oci_core_instance_configuration.pool_instance_configuration.id
  size                      = var.replicas

  dynamic "placement_configurations" {
    for_each = local.pool_placements

    content {
      availability_domain = placement_configurations.key
      fault_domains       = length(placement_configurations.value) > 0 ? placement_configurations.value : null

      # Not primary_subnet_id, which the API deprecates for this block.
      primary_vnic_subnets {
        subnet_id = var.subnet_id != null ? var.subnet_id : local.node_subnet_id
      }
    }
  }

  # size is the desired count the autoscaler owns. A Kubernetes version
  # change replaces the pool, as for the fixed pool.
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [size]
    replace_triggered_by  = [terraform_data.kubernetes_version_roll]
  }
}
