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

# Unit tests of the machinepool role with a mocked OCI provider: no tenancy
# is contacted. Run from the role directory: `terraform test` or `tofu test`
# (`make unit-test` runs both). captf_cluster_outputs is what the cluster
# role exports for a three-AD region; the pool has three running members, one
# per availability domain.

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

run "happy_path" {
  assert {
    condition     = length(output.dropped_node_labels) == 0
    error_message = "Without node labels nothing is dropped."
  }
  assert {
    condition     = output.provider_id == oci_core_instance_pool.fixed_instance_pool[0].id
    error_message = "provider_id must be the instance pool's OCID."
  }
  assert {
    condition = output.provider_id_list == tolist([
      "oci://ocid1.instance.oc1.iad.aaaaaaaamember1",
      "oci://ocid1.instance.oc1.iad.aaaaaaaamember2",
      "oci://ocid1.instance.oc1.iad.aaaaaaaamember3",
    ])
    error_message = "provider_id_list must hold oci://<OCID> of every member, sorted."
  }
  assert {
    condition     = output.replicas == 3
    error_message = "replicas must be the pool's size as OCI reports it."
  }
  assert {
    condition = output.instances == [
      { provider_id = "oci://ocid1.instance.oc1.iad.aaaaaaaamember1", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember1", addresses = [], failure_domain = "US-ASHBURN-AD-1", state = "running" },
      { provider_id = "oci://ocid1.instance.oc1.iad.aaaaaaaamember2", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember2", addresses = [], failure_domain = "US-ASHBURN-AD-2", state = "running" },
      { provider_id = "oci://ocid1.instance.oc1.iad.aaaaaaaamember3", instance_id = "ocid1.instance.oc1.iad.aaaaaaaamember3", addresses = [], failure_domain = "US-ASHBURN-AD-3", state = "running" },
    ]
    error_message = "instances must report every member with its failure domain and health state."
  }
  assert {
    condition     = output.health.state == "running" && output.health.healthy && length(output.health.reasons) == 0 && output.health.message == "instance pool is RUNNING; 3 of 3 instances running"
    error_message = "A running pool at its desired size with every member running is healthy."
  }
  assert {
    condition     = oci_core_instance_pool.fixed_instance_pool[0].size == 3 && oci_core_instance_pool.fixed_instance_pool[0].instance_configuration_id == oci_core_instance_configuration.pool_instance_configuration.id
    error_message = "The pool runs replicas instances of the current instance configuration."
  }
  assert {
    condition     = [for p in oci_core_instance_pool.fixed_instance_pool[0].placement_configurations : p.availability_domain] == ["Uocm:US-ASHBURN-AD-1", "Uocm:US-ASHBURN-AD-2", "Uocm:US-ASHBURN-AD-3"]
    error_message = "The pool spreads over the cluster's availability domains, one placement each."
  }
  assert {
    condition     = alltrue([for p in oci_core_instance_pool.fixed_instance_pool[0].placement_configurations : p.primary_vnic_subnets[0].subnet_id == "ocid1.subnet.oc1.iad.aaaaaaaaworkers"])
    error_message = "Pool instances go in the worker subnet."
  }
  assert {
    condition     = oci_core_instance_pool.fixed_instance_pool[0].display_name == "captf-team-a-demo-demo-pool-0-${substr(sha256("team-a/demo/demo-pool-0"), 0, 8)}"
    error_message = "Pool names derive from the cluster and the MachinePool plus a hash."
  }
  assert {
    condition     = strcontains(base64decode(nonsensitive(oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].metadata["user_data"])), "Content-Type: text/plain; charset=\"utf-8\"\nMIME-Version: 1.0\nContent-Transfer-Encoding: base64\nContent-Disposition: attachment; filename=\"bootstrap\"\n\nI2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIGhlbGxvXQo=\n--==CAPTF-BOUNDARY==--")
    error_message = "cloud-config bootstrap data goes, unchanged, into the second part of the user data's MIME multipart."
  }
  assert {
    condition     = strcontains(base64decode(nonsensitive(oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].metadata["user_data"])), "captf_node_labels=''")
    error_message = "Without node labels the boothook still runs the shared fragment, which removes what an earlier boot wrote."
  }
  assert {
    condition     = oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].create_vnic_details[0].nsg_ids == toset(["ocid1.networksecuritygroup.oc1.iad.aaaaaaaaworkers"]) && oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].create_vnic_details[0].assign_public_ip == false
    error_message = "Pool instances join the worker NSG without a public IP."
  }
  assert {
    condition     = oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].instance_options[0].are_legacy_imds_endpoints_disabled && oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].is_pv_encryption_in_transit_enabled
    error_message = "Legacy instance metadata is off and in-transit encryption on."
  }
  assert {
    condition     = oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].shape == "VM.Standard.E5.Flex" && oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].shape_config[0].ocpus == 2 && oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].source_details[0].image_id == "ocid1.image.oc1.iad.aaaaaaaanode"
    error_message = "Pool instances use the default shape and image_id."
  }
  assert {
    condition     = terraform_data.kubernetes_version_roll.output == "v1.34.1"
    error_message = "The roll trigger tracks kubernetes_version."
  }
}

# Must follow happy_path directly: OpenTofu 1.12 reports an unknown condition
# for outputs of an earlier, non-adjacent run. Mocks never plan a
# replacement, so this proves only that nothing in the configuration churns;
# provider normalisation is DESIGN.md "Unverified" 7.
run "reapply_is_stable" {
  variables {
    previous_pool_id = run.happy_path.provider_id
  }

  assert {
    condition     = output.provider_id == var.previous_pool_id
    error_message = "A second identical apply must keep the pool."
  }
}

# The real rotation path: the provider replaces the instance configuration
# (instance_details is ForceNew), which mocks never plan, so the run forces
# it. On Terraform the new configuration gets the sentinel id and the pool
# must follow it in place; OpenTofu 1.12 overrides every instance, so there
# only the in-place pool id is meaningful. Must follow
# reapply_is_stable directly (see there).
run "instance_configuration_replaced_pool_kept" {
  variables {
    previous_pool_id = run.reapply_is_stable.provider_id
    # base64 of "#cloud-config\nruncmd: [echo rotated]\n"
    bootstrap_data = "I2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIHJvdGF0ZWRdCg=="
  }

  plan_options {
    replace = [oci_core_instance_configuration.pool_instance_configuration]
  }

  override_resource {
    target = oci_core_instance_configuration.pool_instance_configuration
    values = {
      id = "ocid1.instanceconfiguration.oc1.iad.aaaaaaaarotated"
    }
  }

  assert {
    condition     = output.provider_id == var.previous_pool_id
    error_message = "A new instance configuration must update the pool in place, never replace it."
  }
  assert {
    condition     = oci_core_instance_pool.fixed_instance_pool[0].instance_configuration_id == "ocid1.instanceconfiguration.oc1.iad.aaaaaaaarotated"
    error_message = "The pool must switch to the new instance configuration."
  }
}

# A plan: on Terraform a replacement leaves the pool's id unknown and fails
# the comparison. OpenTofu 1.12's mocks know new objects' values at plan
# time, so only the Terraform run proves it. Must follow
# instance_configuration_replaced_pool_kept directly (see reapply_is_stable).
run "bootstrap_rotation_in_place" {
  command = plan

  variables {
    previous_pool_id = run.instance_configuration_replaced_pool_kept.provider_id
    # base64 of "#cloud-config\nruncmd: [echo again]\n"
    bootstrap_data = "I2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIGFnYWluXQo="
  }

  assert {
    condition     = oci_core_instance_pool.fixed_instance_pool[0].id == var.previous_pool_id
    error_message = "A bootstrap rotation must update the pool in place, never replace it (and its running instances)."
  }
  assert {
    condition     = strcontains(base64decode(nonsensitive(oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].metadata["user_data"])), "\n\nI2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIGFnYWluXQo=\n")
    error_message = "New instances must get the rotated bootstrap data."
  }
}

# Terraform applies an override only to an object it creates, so the
# sentinel id proves the replacement there; OpenTofu 1.12 applies it to
# every instance, which makes this run weaker on OpenTofu.
run "kubernetes_version_rolls" {
  variables {
    kubernetes_version = "v1.35.0"
  }

  override_resource {
    target = oci_core_instance_pool.fixed_instance_pool
    values = {
      actual_size = 3
      id          = "ocid1.instancepool.oc1.iad.aaaaaaaarolled"
      state       = "RUNNING"
    }
  }

  assert {
    condition     = output.provider_id == "ocid1.instancepool.oc1.iad.aaaaaaaarolled"
    error_message = "A Kubernetes version change must replace the pool, rolling its instances."
  }
  assert {
    condition     = terraform_data.kubernetes_version_roll.output == "v1.35.0"
    error_message = "The roll trigger must follow kubernetes_version."
  }
}

# Terraform proves the replacement, OpenTofu checks less (see above).
run "kubernetes_version_suffix_rolls" {
  variables {
    kubernetes_version = "v1.35.0+rke2r1"
  }

  override_resource {
    target = oci_core_instance_pool.fixed_instance_pool
    values = {
      actual_size = 3
      id          = "ocid1.instancepool.oc1.iad.aaaaaaaasuffixrolled"
      state       = "RUNNING"
    }
  }

  assert {
    condition     = output.provider_id == "ocid1.instancepool.oc1.iad.aaaaaaaasuffixrolled"
    error_message = "A distribution suffix bump (+rke2rN) is a version change and must roll the pool: the version is compared verbatim."
  }
  assert {
    condition     = terraform_data.kubernetes_version_roll.output == "v1.35.0+rke2r1"
    error_message = "The roll trigger must follow kubernetes_version."
  }
}

run "tags_on_taggable_resources" {
  variables {
    additional_tags = { CostCenter = "42" }
    autoscaling     = { enabled = true, min = 1, max = 5 }
    autoscaled      = true
  }

  assert {
    condition = alltrue([for t in [
      oci_core_instance_pool.autoscaled_instance_pool[0].freeform_tags,
      oci_core_instance_configuration.pool_instance_configuration.freeform_tags,
      oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].freeform_tags,
      oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].create_vnic_details[0].freeform_tags,
      oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration[0].freeform_tags,
      ] : t == tomap({
        "CostCenter"          = "42"
        "captf_io/cluster"    = "demo"
        "captf_io/namespace"  = "team-a"
        "captf_io/kind"       = "TerraformMachinePool"
        "captf_io/name"       = "demo-pool-0"
        "captf_io/managed-by" = "captf"
        "captf_io/template"   = ""
    })])
    error_message = "The pool, the instance configuration with its instances and VNICs, and the autoscaling configuration must carry the mapped captf tags and additional_tags."
  }
}

run "autoscaling_disabled" {
  variables {
    autoscaling = { enabled = false, min = 0, max = 0 }
  }

  assert {
    condition     = length(oci_core_instance_pool.fixed_instance_pool) == 1 && length(oci_core_instance_pool.autoscaled_instance_pool) == 0 && length(oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration) == 0
    error_message = "Without autoscaling the pool has a fixed size and no autoscaling configuration."
  }
  assert {
    condition     = oci_core_instance_pool.fixed_instance_pool[0].size == 3
    error_message = "A fixed pool's size is replicas."
  }
}

run "autoscaling_enabled" {
  variables {
    autoscaling = { enabled = true, min = 2, max = 6 }
    autoscaled  = true
    replicas    = 4
  }

  assert {
    condition     = length(oci_core_instance_pool.fixed_instance_pool) == 0 && oci_core_instance_pool.autoscaled_instance_pool[0].size == 4
    error_message = "With autoscaling the autoscaled pool is created at replicas."
  }
  assert {
    condition     = output.provider_id == oci_core_instance_pool.autoscaled_instance_pool[0].id
    error_message = "provider_id follows the autoscaled pool."
  }
  assert {
    condition     = oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration[0].auto_scaling_resources[0].id == oci_core_instance_pool.autoscaled_instance_pool[0].id && oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration[0].auto_scaling_resources[0].type == "instancePool"
    error_message = "The autoscaling configuration scales this pool."
  }
  assert {
    condition     = oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration[0].policies[0].capacity[0].min == 2 && oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration[0].policies[0].capacity[0].max == 6 && oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration[0].policies[0].capacity[0].initial == 4
    error_message = "The autoscaler's bounds are the MachinePool's annotations, starting at replicas."
  }
  assert {
    condition     = length(oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration[0].policies[0].rules) == 2
    error_message = "The policy scales out above and in below the CPU thresholds."
  }
}

run "autoscaling_keeps_observed_size" {
  variables {
    autoscaling = { enabled = true, min = 2, max = 6 }
    autoscaled  = true
    replicas    = 5
  }

  assert {
    condition     = oci_core_instance_pool.autoscaled_instance_pool[0].size == 4
    error_message = "With autoscaling an apply must not reset the size the autoscaler owns (ignore_changes = [size])."
  }
  assert {
    condition     = oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration[0].policies[0].capacity[0].initial == 4
    error_message = "A new replicas value must not touch the autoscaling configuration's initial size."
  }
}

run "autoscaling_external" {
  variables {
    autoscaling = { enabled = true, min = 2, max = 6 }
    autoscaled  = true
    autoscaler  = "external"
    replicas    = 5
  }

  assert {
    condition     = length(oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration) == 0
    error_message = "With autoscaler external no autoscaling configuration exists: a scaler outside the module owns the size."
  }
  assert {
    condition     = length(oci_core_instance_pool.autoscaled_instance_pool) == 1 && length(oci_core_instance_pool.fixed_instance_pool) == 0
    error_message = "The pool is the autoscaled one whatever the autoscaler, so switching it does not replace the pool."
  }
  assert {
    condition     = oci_core_instance_pool.autoscaled_instance_pool[0].size == 4 && output.provider_id == oci_core_instance_pool.autoscaled_instance_pool[0].id
    error_message = "An external autoscaler's size is kept: the pool is not resized or replaced."
  }
}

run "autoscaling_external_min_zero" {
  command = plan

  variables {
    autoscaling = { enabled = true, min = 0, max = 5 }
    autoscaled  = true
    autoscaler  = "external"
  }

  assert {
    condition     = length(oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration) == 0
    error_message = "min 0 must be accepted with autoscaler external: the minimum of 1 comes from OCI's autoscaling configuration."
  }
}

run "node_labels_rendered" {
  variables {
    node_labels = {
      "example.com/tier"                                        = "web"
      "node.kubernetes.io/exclude-from-external-load-balancers" = ""
      "node-role.kubernetes.io/worker"                          = ""
      "topology.kubernetes.io/zone"                             = "US-ASHBURN-AD-1"
    }
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].metadata["user_data"])), "captf_node_labels='example.com/tier=web,node.kubernetes.io/exclude-from-external-load-balancers=,topology.kubernetes.io/zone=US-ASHBURN-AD-1'")
    error_message = "The shared fragment must get the allowed labels, sorted and comma-joined."
  }
  assert {
    condition     = output.dropped_node_labels == tolist(["node-role.kubernetes.io/worker"])
    error_message = "dropped_node_labels must list what NodeRestriction forbids."
  }
  assert {
    condition     = !strcontains(base64decode(nonsensitive(oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].metadata["user_data"])), "node-role.kubernetes.io")
    error_message = "Labels the NodeRestriction admission plugin forbids must be dropped."
  }
  assert {
    condition     = strcontains(base64decode(nonsensitive(oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].metadata["user_data"])), "Content-Type: text/cloud-boothook")
    error_message = "The labels must be set by a cloud-init boothook part."
  }
  assert {
    condition     = strcontains(base64decode(nonsensitive(oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].metadata["user_data"])), "captf_rke2_file=/etc/rancher/rke2/config.yaml.d/50-captf-node-labels.yaml")
    error_message = "The boothook must carry the shared fragment, which writes the RKE2 drop-in 50-captf-node-labels.yaml."
  }
  assert {
    condition     = strcontains(base64decode(nonsensitive(oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].metadata["user_data"])), "Content-Type: text/plain; charset=\"utf-8\"\nMIME-Version: 1.0\nContent-Transfer-Encoding: base64\nContent-Disposition: attachment; filename=\"bootstrap\"\n\nI2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIGhlbGxvXQo=\n")
    error_message = "The bootstrap payload must follow as an opaque base64 part that cloud-init sniffs."
  }
}

run "node_labels_gzip_payload" {
  variables {
    node_labels = { "example.com/tier" = "web" }
    # base64 of a gzipped cloud-config (CAPRKE2 gzipUserData)
    bootstrap_data = "H4sIAAAAAAAC/1NOzskvTdFNzs9Ly0znKirNS85NsVKITk3OyFfISM3JyY/lAgDckH8lIwAAAA=="
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].metadata["user_data"])), "Content-Type: application/x-gzip\nMIME-Version: 1.0\nContent-Transfer-Encoding: base64\nContent-Disposition: attachment; filename=\"bootstrap\"\n\nH4sIAAAAAAAC/1NOzskvTdFNzs9Ly0znKirNS85NsVKITk3OyFfISM3JyY/lAgDckH8lIwAAAA==\n--==CAPTF-BOUNDARY==--")
    error_message = "A gzipped payload must be a gzip part, which cloud-init decompresses."
  }
}

run "node_labels_wraps_payload" {
  variables {
    node_labels = { "example.com/tier" = "web" }
    # base64 of a 108-character cloud-config
    bootstrap_data = "I2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIGhlbGxvLCB3b3JsZCwgdGhpcyBpcyBhIGxvbmdlciBjbG91ZC1jb25maWcgcGF5bG9hZF0K"
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].metadata["user_data"])), "\n\nI2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIGhlbGxvLCB3b3JsZCwgdGhpcyBpcyBhIGxvbmdl\nciBjbG91ZC1jb25maWcgcGF5bG9hZF0K\n--==CAPTF-BOUNDARY==--")
    error_message = "The base64 part must be wrapped at 76 characters per line (RFC 2045)."
  }
}

run "node_labels_unsupported_format" {
  command = plan

  variables {
    node_labels      = { "example.com/tier" = "web" }
    bootstrap_format = "ignition"
    # base64 of {"ignition":{"version":"3.4.0"}}
    bootstrap_data = "eyJpZ25pdGlvbiI6eyJ2ZXJzaW9uIjoiMy40LjAifX0="
  }

  expect_failures = [oci_core_instance_configuration.pool_instance_configuration]
}

run "bootstrap_ignition_without_labels" {
  variables {
    node_labels      = {}
    bootstrap_format = "ignition"
    bootstrap_data   = "eyJpZ25pdGlvbiI6eyJ2ZXJzaW9uIjoiMy40LjAifX0="
  }

  assert {
    condition     = nonsensitive(oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].metadata["user_data"]) == "eyJpZ25pdGlvbiI6eyJ2ZXJzaW9uIjoiMy40LjAifX0="
    error_message = "Ignition without node labels passes through unchanged, with no MIME envelope."
  }
}

run "failure_domains_default_to_cluster" {
  variables {
    failure_domains         = []
    cluster_failure_domains = ["US-ASHBURN-AD-2"]
  }

  assert {
    condition     = [for p in oci_core_instance_pool.fixed_instance_pool[0].placement_configurations : p.availability_domain] == ["Uocm:US-ASHBURN-AD-2"]
    error_message = "With no failure_domains the pool uses cluster_failure_domains."
  }
}

run "failure_domains_requested" {
  variables {
    failure_domains = ["US-ASHBURN-AD-3", "US-ASHBURN-AD-1"]
  }

  assert {
    condition     = [for p in oci_core_instance_pool.fixed_instance_pool[0].placement_configurations : p.availability_domain] == ["Uocm:US-ASHBURN-AD-1", "Uocm:US-ASHBURN-AD-3"]
    error_message = "MachinePool.spec.failureDomains wins, in a stable order."
  }
}

run "failure_domains_fault_domain_mode" {
  variables {
    failure_domains         = ["FAULT-DOMAIN-1", "FAULT-DOMAIN-3"]
    cluster_failure_domains = ["FAULT-DOMAIN-1", "FAULT-DOMAIN-2", "FAULT-DOMAIN-3"]
    captf_cluster_outputs = {
      schema                  = "captf.io/oci-cluster/v1"
      region                  = "us-sanjose-1"
      compartment_id          = "ocid1.compartment.oc1..aaaaaaaacluster"
      vcn_id                  = "ocid1.vcn.oc1.sjc.aaaaaaaavcn"
      control_plane_subnet_id = "ocid1.subnet.oc1.sjc.aaaaaaaacontrolplane"
      worker_subnet_id        = "ocid1.subnet.oc1.sjc.aaaaaaaaworkers"
      control_plane_nsg_id    = "ocid1.networksecuritygroup.oc1.sjc.aaaaaaaacontrolplane"
      worker_nsg_id           = "ocid1.networksecuritygroup.oc1.sjc.aaaaaaaaworkers"
      failure_domains = {
        "FAULT-DOMAIN-1" = { availability_domain = "Uocm:US-SANJOSE-1-AD-1", fault_domain = "FAULT-DOMAIN-1" }
        "FAULT-DOMAIN-2" = { availability_domain = "Uocm:US-SANJOSE-1-AD-1", fault_domain = "FAULT-DOMAIN-2" }
        "FAULT-DOMAIN-3" = { availability_domain = "Uocm:US-SANJOSE-1-AD-1", fault_domain = "FAULT-DOMAIN-3" }
      }
      node_defined_tags = { "captf.cluster" = "team-a/demo" }
      api               = null
    }
  }

  assert {
    condition     = length(oci_core_instance_pool.fixed_instance_pool[0].placement_configurations) == 1 && oci_core_instance_pool.fixed_instance_pool[0].placement_configurations[0].availability_domain == "Uocm:US-SANJOSE-1-AD-1" && oci_core_instance_pool.fixed_instance_pool[0].placement_configurations[0].fault_domains == tolist(["FAULT-DOMAIN-1", "FAULT-DOMAIN-3"])
    error_message = "Fault-domain failure domains become one placement in their availability domain, listing the fault domains."
  }
  assert {
    condition     = oci_core_instance_configuration.pool_instance_configuration.instance_details[0].launch_details[0].defined_tags == tomap({ "captf.cluster" = "team-a/demo" })
    error_message = "Pool instances must carry the defined tag the cluster's dynamic group matches."
  }
}

run "externally_managed_with_override" {
  variables {
    captf_cluster_outputs = {}
    external_cluster_exports = {
      schema                  = "captf.io/oci-cluster/v1"
      region                  = "us-phoenix-1"
      compartment_id          = "ocid1.compartment.oc1..aaaaaaaaexternal"
      vcn_id                  = "ocid1.vcn.oc1.phx.aaaaaaaavcn"
      control_plane_subnet_id = "ocid1.subnet.oc1.phx.aaaaaaaacontrolplane"
      worker_subnet_id        = "ocid1.subnet.oc1.phx.aaaaaaaaworkers"
      control_plane_nsg_id    = "ocid1.networksecuritygroup.oc1.phx.aaaaaaaacontrolplane"
      worker_nsg_id           = "ocid1.networksecuritygroup.oc1.phx.aaaaaaaaworkers"
      failure_domains         = { "PHX-AD-1" = { availability_domain = "Uocm:PHX-AD-1" } }
      node_defined_tags       = {}
      api                     = null
    }
    cluster_failure_domains = []
  }

  assert {
    condition     = oci_core_instance_pool.fixed_instance_pool[0].compartment_id == "ocid1.compartment.oc1..aaaaaaaaexternal" && [for p in oci_core_instance_pool.fixed_instance_pool[0].placement_configurations : p.availability_domain] == ["Uocm:PHX-AD-1"]
    error_message = "An externally managed cluster's pools use external_cluster_exports."
  }
}

run "externally_managed_without_override" {
  command = plan

  variables {
    captf_cluster_outputs = {}
  }

  expect_failures = [oci_core_instance_configuration.pool_instance_configuration]
}

run "wrong_exports_schema" {
  command = plan

  variables {
    captf_cluster_outputs = {
      schema = "captf.io/gcp-cluster/v1"
      region = "us-central1"
    }
  }

  expect_failures = [var.captf_cluster_outputs]
}

run "rejects_unknown_failure_domain" {
  command = plan

  variables {
    failure_domains = ["US-ASHBURN-AD-9"]
  }

  expect_failures = [oci_core_instance_configuration.pool_instance_configuration]
}

run "bootstrap_too_large" {
  command = plan

  variables {
    # 36,000 base64 characters: over OCI's 32,000-byte metadata limit.
    bootstrap_data = join("", [for i in range(1000) : "SGVsbG8sIHdvcmxkISBIZWxsbywgd29ybGQh"])
  }

  expect_failures = [oci_core_instance_configuration.pool_instance_configuration]
}

run "rejects_autoscaling_min_zero" {
  command = plan

  variables {
    autoscaling = { enabled = true, min = 0, max = 5 }
    autoscaled  = true
  }

  expect_failures = [oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration]
}

run "rejects_scale_in_above_scale_out" {
  command = plan

  variables {
    autoscaling                       = { enabled = true, min = 1, max = 5 }
    autoscaled                        = true
    autoscaling_scale_in_cpu_percent  = 80
    autoscaling_scale_out_cpu_percent = 70
  }

  expect_failures = [oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration]
}

run "rejects_too_many_tags" {
  command = plan

  variables {
    captf_tags = {
      "captf.io/cluster"    = "demo"
      "captf.io/namespace"  = "team-a"
      "captf.io/kind"       = "TerraformMachinePool"
      "captf.io/name"       = "demo-pool-0"
      "captf.io/managed-by" = "captf"
      "captf.io/template"   = ""
      "captf.io/future"     = "x"
    }
    additional_tags = { a = "1", b = "2", c = "3", d = "4" }
  }

  expect_failures = [oci_core_instance_configuration.pool_instance_configuration]
}

run "rejects_autoscaling_mode_mismatch" {
  command = plan

  variables {
    autoscaling = { enabled = true, min = 1, max = 5 }
    autoscaled  = false
  }

  expect_failures = [oci_core_instance_configuration.pool_instance_configuration]
}

run "rejects_gzipped_ignition" {
  command = plan

  variables {
    bootstrap_format = "ignition"
    # base64 of a gzipped payload
    bootstrap_data = "H4sIAAAAAAAC/1NOzskvTdFNzs9Ly0znKirNS85NsVKITk3OyFfISM3JyY/lAgDckH8lIwAAAA=="
  }

  expect_failures = [oci_core_instance_configuration.pool_instance_configuration]
}
