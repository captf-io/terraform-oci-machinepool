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

# Native autoscaling of the pool on CPU utilization, within the MachinePool's
# autoscaler annotations (machinepool.md "autoscaling (input)"). Only with
# autoscaler = "native": with "external" no configuration exists, so a scaler
# outside the module owns the size and the preconditions below do not apply.
# The metrics come from the Compute Instance Monitoring plugin of the Oracle
# Cloud Agent, which the image must run. Every policy field forces a new
# configuration, so new bounds replace it; a pool holds one configuration at
# a time, hence no create_before_destroy.
resource "oci_autoscaling_auto_scaling_configuration" "pool_autoscaling_configuration" {
  count = var.autoscaling.enabled && var.autoscaler == "native" ? 1 : 0

  compartment_id       = local.compartment_id
  cool_down_in_seconds = var.autoscaling_cool_down_seconds
  display_name         = local.name_prefix
  freeform_tags        = local.tags
  is_enabled           = true

  auto_scaling_resources {
    id   = oci_core_instance_pool.autoscaled_instance_pool[0].id
    type = "instancePool"
  }

  policies {
    display_name = "cpu-threshold"
    policy_type  = "threshold"

    # initial is the size at creation; the autoscaler owns it afterwards.
    capacity {
      initial = var.replicas
      max     = var.autoscaling.max
      min     = var.autoscaling.min
    }

    # metric_source and pending_duration are written out although they are
    # OCI's defaults: the provider reads both back into the rule's set hash,
    # and leaving them unset would plan a replacement on every run.
    rules {
      display_name = "scale-out"

      action {
        type  = "CHANGE_COUNT_BY"
        value = 1
      }

      metric {
        metric_source    = "COMPUTE_AGENT"
        metric_type      = "CPU_UTILIZATION"
        pending_duration = "PT3M"

        threshold {
          operator = "GT"
          value    = var.autoscaling_scale_out_cpu_percent
        }
      }
    }

    rules {
      display_name = "scale-in"

      action {
        type  = "CHANGE_COUNT_BY"
        value = -1
      }

      metric {
        metric_source    = "COMPUTE_AGENT"
        metric_type      = "CPU_UTILIZATION"
        pending_duration = "PT3M"

        threshold {
          operator = "LT"
          value    = var.autoscaling_scale_in_cpu_percent
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [policies[0].capacity[0].initial]

    precondition {
      condition     = var.autoscaling.min >= 1
      error_message = "The MachinePool's autoscaler min-size annotation is 0; this module needs at least 1 until OCI threshold autoscaling at 0 instances is verified (DESIGN.md \"Unverified\")."
    }
    precondition {
      condition     = var.autoscaling_scale_in_cpu_percent < var.autoscaling_scale_out_cpu_percent
      error_message = "autoscaling_scale_in_cpu_percent must be below autoscaling_scale_out_cpu_percent, or the pool scales in and out at once."
    }
  }
}
