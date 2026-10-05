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

# What every pool instance launches with. Instance configurations are
# immutable: a bootstrap rotation (about every 7.5 minutes with kubeadm) or
# any other change creates a new one before the old one is deleted, and the
# pool switches to it in place, so new instances get the current token and
# running ones are left alone (machinepool.md "Bootstrap rotation"; OCI:
# https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/updatinginstancepool-updating-instance-configuration.htm).
# It carries the role's preconditions: every apply goes through it.
resource "oci_core_instance_configuration" "pool_instance_configuration" {
  compartment_id = local.compartment_id
  display_name   = local.name_prefix
  freeform_tags  = local.tags

  instance_details {
    instance_type = "compute"

    launch_details {
      compartment_id = local.compartment_id
      # Lets an operator-managed or the cluster's dynamic group match the
      # nodes; null rather than {} when there is none.
      defined_tags                        = length(local.node_defined_tags) > 0 ? local.node_defined_tags : null
      freeform_tags                       = local.tags
      is_pv_encryption_in_transit_enabled = var.pv_encryption_in_transit
      metadata                            = local.metadata
      shape                               = var.shape

      create_vnic_details {
        assign_public_ip = var.public_ip
        freeform_tags    = local.tags
        nsg_ids          = compact(concat([local.node_nsg_id], var.additional_nsg_ids))
        subnet_id        = var.subnet_id != null ? var.subnet_id : local.node_subnet_id
      }

      # Instance metadata v1 off: v2 requires an "Authorization: Bearer
      # Oracle" header and rejects forwarded requests, which blunts request
      # forgery: https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/gettingmetadata.htm
      instance_options {
        are_legacy_imds_endpoints_disabled = true
      }

      dynamic "preemptible_instance_config" {
        for_each = var.preemptible ? [true] : []

        content {
          preemption_action {
            preserve_boot_volume = false
            type                 = "TERMINATE"
          }
        }
      }

      # Flexible shapes take OCPUs and memory; fixed shapes refuse them.
      dynamic "shape_config" {
        for_each = endswith(var.shape, ".Flex") ? [true] : []

        content {
          memory_in_gbs = var.memory_gib
          ocpus         = var.ocpus
        }
      }

      source_details {
        boot_volume_size_in_gbs = tostring(var.boot_volume_size_gib)
        image_id                = var.image_id
        kms_key_id              = var.boot_volume_kms_key_id
        source_type             = "image"
      }
    }
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = local.exports != null
      error_message = "The TerraformCluster is externally managed (captf_cluster_outputs is {}): set spec.variables.external_cluster_exports on the TerraformMachinePool to the cluster's exports (README \"Exports\")."
    }
    precondition {
      condition     = var.autoscaling.enabled == var.autoscaled
      error_message = "The MachinePool's autoscaler annotations say autoscaling.enabled = ${var.autoscaling.enabled}, but spec.variables.autoscaled is ${var.autoscaled}. Changing modes replaces the pool and terminates every instance in it at once: set autoscaled to match only if that is intended, or fix the annotations (an incomplete, unparsable or min > max pair disables autoscaling)."
    }
    precondition {
      condition     = length(local.unknown_failure_domains) == 0
      error_message = "failure_domains ${join(", ", local.unknown_failure_domains)} are not among the cluster's failure domains: ${join(", ", local.known_failure_domains)}."
    }
    precondition {
      condition     = length(local.node_labels) == 0 || var.bootstrap_format == "cloud-config"
      error_message = "node_labels need bootstrap_format cloud-config: this module renders them as a cloud-init boothook, which Ignition does not run. Remove the MachinePool's template labels or use cloud-config."
    }
    precondition {
      condition     = !(var.bootstrap_format == "ignition" && local.bootstrap_gzipped)
      error_message = "bootstrap_data is gzipped Ignition, which this module refuses: Ignition is not known to decompress its user-data config on OCI. Turn off compression in the bootstrap provider (CAPRKE2 gzipUserData)."
    }
    precondition {
      condition     = local.metadata_bytes <= local.metadata_limit_bytes
      error_message = "The instance metadata (bootstrap data, node labels and SSH keys) is ${local.metadata_bytes} bytes; OCI accepts ${local.metadata_limit_bytes}. Shrink the bootstrap configuration, or gzip it in the bootstrap provider (CAPRKE2 gzipUserData)."
    }
    precondition {
      condition     = length(local.tags) <= 10
      error_message = "OCI allows 10 free-form tags per resource; captf_tags and additional_tags together hold ${length(local.tags)}. Remove entries from additional_tags."
    }
  }
}
