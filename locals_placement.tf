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

# Where the pool's instances go. MachinePool.spec.failureDomains, else the
# cluster's failure domains (machinepool.md "failure_domains (input)"), each
# resolved through the exports into an availability domain and, in
# fault-domain mode, a fault domain. OCI wants one placement configuration
# per availability domain, listing its fault domains.
locals {
  known_failure_domains = sort(keys(local.cluster_failure_domains))
  pool_failure_domains = sort(distinct(
    length(var.failure_domains) > 0 ? var.failure_domains :
    length(var.cluster_failure_domains) > 0 ? var.cluster_failure_domains :
    local.known_failure_domains
  ))
  unknown_failure_domains = [for fd in local.pool_failure_domains : fd if !contains(local.known_failure_domains, fd)]
  placed_failure_domains  = [for fd in local.pool_failure_domains : fd if contains(local.known_failure_domains, fd)]

  # Availability domain -> its fault domains in the pool ([] lets OCI spread
  # over all of them).
  pool_placements = {
    for ad in distinct([for fd in local.placed_failure_domains : local.cluster_failure_domains[fd].availability_domain]) : ad => compact([
      for fd in local.placed_failure_domains : try(local.cluster_failure_domains[fd].fault_domain, "")
      if local.cluster_failure_domains[fd].availability_domain == ad
    ])
  }

  # Placement -> failure domain name, to report where each member runs.
  failure_domain_by_placement = merge(
    { for name, fd in local.cluster_failure_domains : fd.availability_domain => name if try(fd.fault_domain, null) == null },
    { for name, fd in local.cluster_failure_domains : "${fd.availability_domain}/${fd.fault_domain}" => name if try(fd.fault_domain, null) != null },
  )
}
