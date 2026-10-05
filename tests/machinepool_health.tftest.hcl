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

# Pool health and membership: what provider_id_list, replicas, instances
# and health report for each pool and member state (locals_health.tf). Runs
# override the pool's member list, and replace the pool where its own state
# or size must change. Mocks and variables are those of machinepool.tftest.hcl.

mock_provider "oci" {
  mock_resource "oci_core_instance_pool" {
    defaults = {
      actual_size  = 3
      current_size = 3
      state        = "RUNNING"
    }
  }
  mock_data "oci_core_instance_pool_instances" {
    defaults = {
      instances = [
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-1", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-a1b2c", fault_domain = "FAULT-DOMAIN-2", id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Running", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-2", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-d3e4f", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Running", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-3", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-g5h6i", fault_domain = "FAULT-DOMAIN-3", id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Running", time_created = "2026-10-01 12:00:00 +0000 UTC" },
      ]
    }
  }
}

variables {
  captf_contract = "v1alpha1"
  captf_cluster  = { name = "demo", namespace = "team-a" }
  captf_object   = { kind = "TerraformMachinePool", name = "demo-pool-0", namespace = "team-a" }
  captf_cluster_outputs = {
    schema                  = "captf.io/oci-cluster/v1"
    region                  = "us-ashburn-1"
    compartment_id          = "ocid1.compartment.oc1..aaaaaaaacluster"
    vcn_id                  = "ocid1.vcn.oc1.iad.aaaaaaaavcn"
    control_plane_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaacontrolplane"
    worker_subnet_id        = "ocid1.subnet.oc1.iad.aaaaaaaaworkers"
    control_plane_nsg_id    = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaacontrolplane"
    worker_nsg_id           = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaaworkers"
    failure_domains = {
      "US-ASHBURN-AD-1" = { availability_domain = "Uocm:US-ASHBURN-AD-1" }
      "US-ASHBURN-AD-2" = { availability_domain = "Uocm:US-ASHBURN-AD-2" }
      "US-ASHBURN-AD-3" = { availability_domain = "Uocm:US-ASHBURN-AD-3" }
    }
    node_defined_tags = {}
    api = {
      network_load_balancer_id = "ocid1.networkloadbalancer.oc1.iad.aaaaaaaaapi"
      backend_sets             = { "api-server" = 6443 }
    }
  }
  captf_tags = {
    "captf.io/cluster"    = "demo"
    "captf.io/namespace"  = "team-a"
    "captf.io/kind"       = "TerraformMachinePool"
    "captf.io/name"       = "demo-pool-0"
    "captf.io/managed-by" = "captf"
    "captf.io/template"   = ""
  }
  machinepool_name = "demo-pool-0"
  replicas         = 3
  # base64 of "#cloud-config\nruncmd: [echo hello]\n"
  bootstrap_data          = "I2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIGhlbGxvXQo="
  bootstrap_format        = "cloud-config"
  failure_domains         = []
  cluster_failure_domains = ["US-ASHBURN-AD-1", "US-ASHBURN-AD-2", "US-ASHBURN-AD-3"]
  kubernetes_version      = "v1.34.1"
  node_labels             = {}
  autoscaling             = { enabled = false, min = 0, max = 0 }

  image_id = "ocid1.image.oc1.iad.aaaaaaaanode"
}

run "membership_excludes_terminated" {
  override_data {
    target = data.oci_core_instance_pool_instances.pool_members
    values = {
      instances = [
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-1", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-1", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Running", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-2", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-2", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Running", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-3", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-3", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Terminated", time_created = "2026-10-01 12:00:00 +0000 UTC" },
      ]
    }
  }

  assert {
    condition     = output.provider_id_list == tolist(["oci://ocid1.instance.oc1.iad.aaaaaaaamember1", "oci://ocid1.instance.oc1.iad.aaaaaaaamember2"])
    error_message = "A TERMINATED member must leave provider_id_list; every other member stays."
  }
  assert {
    condition     = length(output.instances) == 2
    error_message = "instances must list the same members as provider_id_list."
  }
  assert {
    condition     = output.health.state == "running" && !output.health.healthy && output.health.reasons == tolist(["ScalingInProgress"])
    error_message = "Two running members of three desired: running, not yet healthy."
  }
}

run "membership_keeps_unhealthy_members" {
  override_data {
    target = data.oci_core_instance_pool_instances.pool_members
    values = {
      instances = [
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-1", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-1", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Running", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-2", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-2", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Starting", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-3", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-3", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Stopped", time_created = "2026-10-01 12:00:00 +0000 UTC" },
      ]
    }
  }

  assert {
    condition     = length(output.provider_id_list) == 3
    error_message = "Starting and stopped members stay in provider_id_list: CAPI deletes the Node of any provider ID that leaves it."
  }
  assert {
    condition     = output.health.state == "stopped" && !output.health.healthy
    error_message = "The worst of degraded, stopped and unknown wins; a starting member never makes the pool pending."
  }
  assert {
    condition     = output.health.reasons == tolist(["InstanceStopped:ocid1.instance.oc1.iad.aaaaaaaamember3"])
    error_message = "reasons must name each degraded, stopped or unknown instance with its OCI state."
  }
  assert {
    condition     = [for i in output.instances : i.state] == ["running", "pending", "stopped"]
    error_message = "Each instance reports its own health state."
  }
}

run "health_unknown_member_state" {
  override_data {
    target = data.oci_core_instance_pool_instances.pool_members
    values = {
      instances = [
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-1", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-1", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "RUNNING", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-2", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-2", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "RUNNING", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-3", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-3", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "CREATING_IMAGE", time_created = "2026-10-01 12:00:00 +0000 UTC" },
      ]
    }
  }

  assert {
    condition     = output.health.state == "unknown" && !output.health.healthy && output.health.reasons == tolist(["InstanceCreatingImage:ocid1.instance.oc1.iad.aaaaaaaamember3"])
    error_message = "A member taking a custom image is unknown."
  }
}

run "membership_excludes_terminating" {
  override_data {
    target = data.oci_core_instance_pool_instances.pool_members
    values = {
      instances = [
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-1", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-1", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "RUNNING", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-2", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-2", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "RUNNING", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-3", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-3", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "TERMINATING", time_created = "2026-10-01 12:00:00 +0000 UTC" },
      ]
    }
  }

  assert {
    condition     = output.health.state == "running" && !output.health.healthy && output.health.reasons == tolist(["ScalingInProgress"]) && length(output.provider_id_list) == 2
    error_message = "A TERMINATING member is being deleted: not a member, and the pool is scaling back up."
  }
}

run "health_starting_members" {
  override_data {
    target = data.oci_core_instance_pool_instances.pool_members
    values = {
      instances = [
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-1", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-1", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "RUNNING", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-2", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-2", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "RUNNING", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-3", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-3", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "STARTING", time_created = "2026-10-01 12:00:00 +0000 UTC" },
      ]
    }
  }

  assert {
    condition     = output.health.state == "running" && !output.health.healthy && output.health.reasons == tolist(["InstanceStarting:ocid1.instance.oc1.iad.aaaaaaaamember3"])
    error_message = "A starting member keeps the pool running but not yet healthy, and is named."
  }
}

run "health_no_members_yet" {
  override_data {
    target = data.oci_core_instance_pool_instances.pool_members
    values = {
      instances = []
    }
  }

  assert {
    condition     = output.health.state == "pending" && !output.health.healthy && output.health.reasons == tolist(["NoMembers"]) && length(output.provider_id_list) == 0
    error_message = "A pool whose first members do not exist yet is pending."
  }
}

run "health_pool_stopped" {
  plan_options {
    replace = [oci_core_instance_pool.fixed_instance_pool[0]]
  }

  override_resource {
    target = oci_core_instance_pool.fixed_instance_pool
    values = {
      actual_size  = 3
      current_size = 0
      state        = "STOPPED"
    }
  }
  override_data {
    target = data.oci_core_instance_pool_instances.pool_members
    values = {
      instances = [
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-1", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-1", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember1", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Stopped", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-2", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-2", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember2", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Stopped", time_created = "2026-10-01 12:00:00 +0000 UTC" },
        { auto_terminate_instance_on_delete = false, availability_domain = "Uocm:US-ASHBURN-AD-3", compartment_id = "ocid1.compartment.oc1..aaaaaaaacluster", decrement_size_on_delete = false, display_name = "inst-3", fault_domain = "FAULT-DOMAIN-1", id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_configuration_id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaaconfig", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember3", instance_pool_id = "ocid1.instancepool.oc1.iad.aaaaaaaapool", load_balancer_backends = [], region = "iad", shape = "VM.Standard.E5.Flex", state = "Stopped", time_created = "2026-10-01 12:00:00 +0000 UTC" },
      ]
    }
  }

  assert {
    condition     = output.health.state == "stopped" && !output.health.healthy && contains(output.health.reasons, "InstanceStopped:ocid1.instance.oc1.iad.aaaaaaaamember1")
    error_message = "A stopped pool's members are stopped, and say so."
  }
}

run "zero_replicas_healthy" {
  variables {
    replicas = 0
  }

  plan_options {
    replace = [oci_core_instance_pool.fixed_instance_pool[0]]
  }

  override_resource {
    target = oci_core_instance_pool.fixed_instance_pool
    values = {
      actual_size  = 0
      current_size = 0
      state        = "RUNNING"
    }
  }
  override_data {
    target = data.oci_core_instance_pool_instances.pool_members
    values = {
      instances = []
    }
  }

  assert {
    condition     = output.health.state == "running" && output.health.healthy && length(output.health.reasons) == 0
    error_message = "A pool scaled to zero is running and healthy."
  }
  assert {
    condition     = output.replicas == 0 && length(output.provider_id_list) == 0 && length(output.instances) == 0
    error_message = "Zero replicas report an empty membership."
  }
}
