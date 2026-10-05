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

# Cloud resource names, derived from the Cluster and the MachinePool with a
# hash that keeps truncated names unique (CONVENTIONS.md section 6).
locals {
  pool_key  = "${var.captf_cluster.namespace}/${var.captf_cluster.name}/${var.machinepool_name}"
  pool_hash = substr(sha256(local.pool_key), 0, 8)
  # Display names allow 255 characters; 63 (a DNS label) keeps them readable
  # in the console, where OCI also shows the pool's instances.
  name_max = 63
  # name_max - 9 leaves room for "-" and the hash.
  name_prefix = "${trimsuffix(substr(lower("captf-${var.captf_cluster.namespace}-${var.captf_cluster.name}-${var.machinepool_name}"), 0, local.name_max - 9), "-")}-${local.pool_hash}"
}
