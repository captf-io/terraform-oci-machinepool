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

# The pool at a fixed size, when autoscaling is off: size follows replicas,
# and an out-of-band resize shows as drift. The provider overwrites size from
# the cloud on every read and OCI pools have no min/max to pin, so the
# autoscaled pool is a separate resource rather than this one with
# ignore_changes (DESIGN.md decision 6); switching modes replaces the pool.
resource "oci_core_instance_pool" "fixed_instance_pool" {
  count = var.autoscaling.enabled ? 0 : 1

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

  # A Kubernetes version change replaces the pool: the new one comes up at
  # the current size before the old one and its instances go (machinepool.md
  # "Lifecycle"). A new instance configuration alone updates it in place.
  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [terraform_data.kubernetes_version_roll]
  }
}
