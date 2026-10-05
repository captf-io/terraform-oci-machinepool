# Design: terraform-oci-machinepool

Why these modules look the way they do. Each decision names the evidence it
rests on; anything not yet checked against a real tenancy is listed under
"Unverified" and must be confirmed on the first reviewed apply.

Pins: `oracle/oci` 9.8.0. Runtimes: Terraform >= 1.5, OpenTofu >= 1.6.
Conventions: [CONVENTIONS.md](CONVENTIONS.md). Contract:
<https://captf.io/docs/module-author/contract/v1alpha1/>.

Provider facts below were read from the 9.8.0 sources
(`internal/service/<service>/*_resource.go`, `internal/provider/provider.go`,
`internal/tfresource/retry.go`) and `providers schema -json` of the pinned
provider; "ForceNew" means the attribute forces a replacement there.

The decision and "Unverified" numbers are the same in every terraform-oci-*
repository (they follow the cloud's original DESIGN.md), so a citation such as
"decision 6" means the same thing everywhere. A section that only concerns
another role is a one-line pointer under its original number.

## Scope

- One role, `machinepool`: one instance pool per `TerraformMachinePool`.. The other roles are in
  [terraform-oci-cluster](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md) and
  [terraform-oci-machine](https://github.com/captf-io/terraform-oci-machine/blob/main/DESIGN.md).
- Cluster exports consumed (schema `captf.io/oci-cluster/v1`, defined in
  the [cluster repository's DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#exports-captfiooci-clusterv1)):
  `region`, `compartment_id`, `worker_subnet_id`, `worker_nsg_id`,
  `failure_domains` and `node_defined_tags`.

## Decisions

### 1. API Network Load Balancer

Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#1-api-network-load-balancer).

### 2. Network security groups

Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#2-network-security-groups).

### 3. Failure domains

Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#3-failure-domains).

### 4. Node identity

Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#4-node-identity).

### 5. Machine

Concerns the machine role: see [terraform-oci-machine DESIGN.md](https://github.com/captf-io/terraform-oci-machine/blob/main/DESIGN.md#5-machine). Pool instances follow its settings; the kubelet provider ID applies to them too:

- The kubelet sets `--provider-id=oci://{{ v1.instance_id }}` in the
  examples: CABPK's cloud-config is a Jinja template and cloud-init's
  Oracle datasource sets `instance-id` to the instance OCID
  (`DataSourceOracle.py`), so the Node carries the module's `provider_id`
  from its first registration, CCM or not.

### 6. Machine pool


- Instance configurations are immutable (`instance_details` is ForceNew). A
  bootstrap rotation creates a new configuration (`create_before_destroy`)
  and updates the pool's `instance_configuration_id` in place (nothing on
  `oci_core_instance_pool` is ForceNew but `compute_cluster_id`); existing
  instances keep running and new ones get the current token
  (<https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/updatinginstancepool-updating-instance-configuration.htm>).
- A Kubernetes version change replaces the pool through
  `replace_triggered_by = [terraform_data.kubernetes_version_roll]`, create
  before destroy: the new pool comes up at the current size, then the old
  one is deleted and its members leave `provider_id_list`. The group
  `provider_id` changes, which the controller allows. An image change alone
  does not roll.
- Two pool resources, `fixed_instance_pool` and `autoscaled_instance_pool`,
  counted by `var.autoscaling.enabled`. The provider overwrites `size` from
  the cloud on every read (`core_instance_pool_resource.go`, "update the
  size as well if it was modified outside terraform"), and OCI pools have no
  min/max to pin, so one pool with `ignore_changes = [size]` would ignore
  `replicas` while autoscaling is off. Switching modes replaces the pool
  (documented). tfcapi-lint's regex does not know `size` and warns
  (`pool/autoscaling-ignore-changes`, allowed with this reason). Because a
  mistyped annotation renders `autoscaling.enabled = false` (contract), a
  mode switch would silently replace the pool and all its instances, so a
  precondition requires the user variable `autoscaled` to match: the switch
  takes a deliberate second edit. Both pools carry `create_before_destroy`,
  but it does not order a destroy and a create at two different addresses,
  so a mode switch still removes the old pool's instances at once; the
  guard makes that a choice.
- Rejected: one pool with `ignore_changes = [size]` and an always-present
  autoscaling configuration pinned to `min = max = replicas` when autoscaling
  is off. Every policy field is ForceNew, so each `replicas` change would
  replace the configuration and resize the pool only through `initial`,
  whose resize behaviour is unverified (Unverified 4); `replicas = 0`, which
  fixed pools must support, needs an autoscaling minimum of 0, also
  unverified; and every fixed pool would depend on the monitoring agent.
- Autoscaling: `oci_autoscaling_auto_scaling_configuration` with a CPU
  threshold policy (scale out above, in below, by one instance) and
  capacity from `var.autoscaling`. Every policy field is ForceNew, so new
  bounds replace the configuration (a pool takes one at a time, so no
  create-before-destroy). `capacity.initial` is `replicas` at creation and
  then ignored, or each observed size change would replace it. The rules'
  `metric_source = "COMPUTE_AGENT"` and `pending_duration = "PT3M"` are
  written out: the provider reads both back into the rules' set hash
  (`MetricBaseToMap`, `rulesHashCodeForSets`), so leaving them unset would
  plan a replacement on every run.
- Membership: `data.oci_core_instance_pool_instances` (id, AD, fault
  domain, state; no addresses), TERMINATED excluded, states compared after
  `upper()` (the SDK's `InstanceSummary.State` is a free string). The data
  source is counted on the pool's existence: a pool dropped from state
  (TERMINATED, see decision 5) leaves no id, and an uncounted read would
  fail every refresh and the destroy's. `replicas` is the pool's
  `actual_size`, which the provider sets from the API's `size` (the
  configured size the autoscaler changes) on every read
  (`core_instance_pool_resource.go`, `s.D.Set("actual_size", *s.Res.Size)`);
  `current_size` is the running count. Addresses would need a lookup per
  member, and `for_each` over ids unknown before the pool exists fails the
  first plan.
- Bootstrap and node labels: a cloud-config payload always goes in a MIME
  multipart (the shared `user_data.mime.tftpl`) of a `text/cloud-boothook`
  part running the shared node-labels fragment (`node_labels.tftpl`,
  identical in every pool module; it also removes its own output when there
  are no labels) and the bootstrap payload as a base64 part, `text/plain` (cloud-init sniffs the
  type, so CABPK's `## template: jinja` header still works) or
  `application/x-gzip` (cloud-init decompresses, then sniffs); see
  `_process_msg` in cloud-init's `user_data.py`. Labels the kubelet may not
  self-assign are dropped (`IsKubeletLabel`, `k8s.io/kubelet`
  `well_known_labels.go`).

### 7. provider_id, addresses, health

- `oci://<instance-ocid>`: oci-cloud-controller-manager v1.36.0 implements
  Instances v1 and cloud-provider builds `ProviderName() + "://" +
  InstanceID` (`ccm.go` `providerPrefix = providerName + "://"`,
  `k8s.io/cloud-provider` `GetInstanceProviderID`).
- Addresses: InternalIP (private IP), ExternalIP when public; the same set
  the CCM reports for IPv4 (`extractNodeAddresses`, `instances.go`).
- Health from instance `state`: PROVISIONING, STARTING → pending; RUNNING,
  MOVING → running; CREATING_IMAGE → unknown; STOPPING, STOPPED → stopped;
  TERMINATING, TERMINATED → terminated; gone from state → terminated. The
  enum is `InstanceLifecycleStateEnum` in oci-go-sdk v65.126.1, the
  provider's SDK.
- Pool health follows CONVENTIONS.md section 10: a pool gone from state,
  TERMINATING or TERMINATED is terminated; members TERMINATING or
  TERMINATED are not members (`InstancePoolLifecycleStateEnum`,
  `InstanceLifecycleStateEnum`).

### 8. Subnet checks and teardown

Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#8-subnet-checks-and-teardown).

### 9. Tags


Free-form tag keys cannot contain periods or spaces, are case-insensitive,
and a resource carries at most 10 free-form tags
(<https://docs.oracle.com/en-us/iaas/Content/Tagging/Concepts/taggingoverview.htm>,
"Limits on Tags": keys printable ASCII without periods or spaces, at most
100 characters; values at most 256). Mapping: `.` and space to `_`
(`captf.io/cluster` → `captf_io/cluster`); values unchanged. The six captf
tags leave four slots, so `additional_tags` takes at most four entries, and
a precondition on each role's primary resource checks the total. Provider
blocks set `ignore_defined_tags = ["Oracle-Tags.CreatedBy",
"Oracle-Tags.CreatedOn"]` plus the user's `ignore_defined_tags`, so tenancy
tag defaults cause no drift. Not taggable: NSG rules, backend sets,
listeners and backends.

### 10. Credentials


Every provider argument falls back to `TF_VAR_<attr>` and then
`OCI_<ATTR>` (`MultiEnvDefaultFunc` with `tfVarName`/`ociVarName` in
`provider.go` 9.8.0); CAPTF drops `TF_VAR_*`, so the identity uses the
`OCI_*` forms:

```yaml
OCI_TENANCY_OCID: ocid1.tenancy.oc1..<id>
OCI_USER_OCID: ocid1.user.oc1..<id>
OCI_FINGERPRINT: "<aa:bb:...>"
OCI_PRIVATE_KEY_PATH: /var/run/captf/credentials/oci_api_key.pem
oci_api_key.pem: <PEM>
```

`OCI_PRIVATE_KEY` would take precedence over the path, so it is not used.
Config-file profiles read `$HOME/.oci/config`, and the runner sets `HOME`
to `/captf/work`, so profiles (and SecurityToken auth) are unusable. A
management cluster running on OCI can use `OCI_AUTH=InstancePrincipal`.
Modules set the region explicitly: `region` on the cluster, the exports'
region on machines and pools.


## Unverified

**1.** Whether OCI accepts empty free-form tag values (`captf.io/template`).

**2.** Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#unverified).

**3.** Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#unverified).

**4.** Autoscaling capacity minimum 0 (rejected by a precondition until
verified); whether `capacity.initial` is required, and whether creating
the configuration resizes an existing pool to it.

**5.** Casing of member `state` values from the pool data source (normalised
with `upper()`), and whether TERMINATING members are listed.

**6.** Deleting an instance configuration that running instances came from.

**7.** Idempotency of `shape_config`, `source_details`, defined tags and the
autoscaling rules' read-back (first real apply must show an empty second
plan).

**8.** Concerns the machine role: see [terraform-oci-machine DESIGN.md](https://github.com/captf-io/terraform-oci-machine/blob/main/DESIGN.md#unverified).

**9.** In-transit encryption (`is_pv_encryption_in_transit_enabled`) on custom
images such as image-builder's.

**10.** Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#unverified).

## Rejected alternatives

- One pool with `ignore_changes = [size]` (ignores `replicas` when
  autoscaling is off).
- Config-file profiles (no `$HOME/.oci` in the Job).
- `capacity.initial` following `replicas` (ForceNew: every observed scale
  would replace the autoscaling configuration).
- Per-member instance lookups for pool addresses (`for_each` over ids
  unknown before the pool exists).
- OCI's pre-termination lifecycle action on pools: it only delays
  termination; draining needs an in-cluster handler, out of scope with
  MachinePool Machines.
