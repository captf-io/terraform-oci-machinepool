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

# The pool's members, re-read on every refresh so provider_id_list, instances
# and health follow scaling and terminations (machinepool.md "Membership
# refresh"). It reports placement and state, not addresses. Counted: a pool
# that has vanished (the provider drops a TERMINATED pool from state on read)
# leaves no id to read members by, and an uncounted read would fail every
# refresh and the destroy's.
data "oci_core_instance_pool_instances" "pool_members" {
  count = local.pool != null ? 1 : 0

  compartment_id   = local.compartment_id
  instance_pool_id = local.pool_id
}
