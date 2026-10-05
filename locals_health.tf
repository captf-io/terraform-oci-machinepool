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

# Pool health and membership, in the order CONVENTIONS.md section 10 gives
# (machinepool.md "Deriving group health"). Members come from the pool's
# instance list; one whose state means deletion is not a member.
locals {
  pool       = one(concat(oci_core_instance_pool.fixed_instance_pool, oci_core_instance_pool.autoscaled_instance_pool))
  pool_id    = try(local.pool.id, null)
  pool_state = try(upper(local.pool.state), null)
  # The pool's size as OCI reports it: what the autoscaler decided, when it
  # owns the size (the provider refreshes actual_size on every read).
  desired_size = try(local.pool.actual_size, null)

  # OCI instance lifecycle state -> contract health state and reason; the
  # same mapping as the machine role. TERMINATING and TERMINATED mean
  # deletion: such an instance is not a member.
  instance_health_by_state = {
    PROVISIONING   = { state = "pending", reason = "InstanceProvisioning" }
    STARTING       = { state = "pending", reason = "InstanceStarting" }
    RUNNING        = { state = "running", reason = null }
    MOVING         = { state = "running", reason = null }
    CREATING_IMAGE = { state = "unknown", reason = "InstanceCreatingImage" }
    STOPPING       = { state = "stopped", reason = "InstanceStopping" }
    STOPPED        = { state = "stopped", reason = "InstanceStopped" }
    TERMINATING    = { state = "terminated", reason = "InstanceNotFound" }
    TERMINATED     = { state = "terminated", reason = "InstanceNotFound" }
  }
  # Pool states that mean deletion.
  pool_deleted_states = ["TERMINATING", "TERMINATED"]

  # Every member, whatever its health: CAPI deletes the Node of a provider
  # ID that leaves the list (machinepool.md "provider_id_list"). upper(): the
  # casing of member states is not documented.
  members = [
    for m in [
      for i in try(data.oci_core_instance_pool_instances.pool_members[0].instances, []) : {
        id                  = i.id
        availability_domain = i.availability_domain
        fault_domain        = i.fault_domain
        health              = lookup(local.instance_health_by_state, upper(i.state), { state = "unknown", reason = "UnknownState" })
      }
    ] : merge(m, { state = m.health.state }) if m.health.state != "terminated"
  ]
  unhealthy_members = [for m in local.members : m if contains(["degraded", "stopped", "unknown"], m.state)]
  starting_members  = [for m in local.members : m if m.state == "pending"]

  pool_gone = local.pool == null || contains(local.pool_deleted_states, coalesce(local.pool_state, "-"))
  health_state = (
    local.pool_gone ? "terminated" :
    local.desired_size == 0 ? "running" :
    length(local.members) == 0 ? "pending" :
    length(local.unhealthy_members) > 0 ? [for s in ["degraded", "stopped", "unknown"] : s if contains([for m in local.unhealthy_members : m.state], s)][0] :
    "running"
  )
  health_healthy = !local.pool_gone && (local.desired_size == 0 || (
    length(local.members) == local.desired_size && length(local.unhealthy_members) == 0 && length(local.starting_members) == 0
  ))
  health_message = (
    local.pool == null ? "instance pool not found" :
    "instance pool is ${local.pool_state}; ${length(local.members) - length(local.unhealthy_members) - length(local.starting_members)} of ${local.desired_size} instances running"
  )
  # Stable, machine-readable: why the pool is unhealthy, then one entry per
  # affected member.
  health_reasons = local.health_healthy ? [] : (
    local.pool_gone ? ["PoolNotFound"] :
    length(local.members) == 0 ? ["NoMembers"] :
    length(local.unhealthy_members) > 0 ? [for m in local.unhealthy_members : "${m.health.reason}:${m.id}"] :
    concat(
      length(local.members) != local.desired_size ? ["ScalingInProgress"] : [],
      [for m in local.starting_members : "${m.health.reason}:${m.id}"],
    )
  )
}
