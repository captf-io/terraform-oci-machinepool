<h1 align="center">
  <a href="https://captf.io/"><img
    src="https://captf.io/assets/readme/mark.svg"
    width="72" height="72" alt="CAPTF"></a>
  <br>
  terraform-oci-machinepool
</h1>

<p align="center">The CAPTF machine pool module for Oracle Cloud</p>

<p align="center">
  <a href="https://github.com/captf-io/terraform-oci-machinepool/actions/workflows/ci.yml"><img
    src="https://img.shields.io/github/actions/workflow/status/captf-io/terraform-oci-machinepool/ci.yml?branch=main&amp;label=build&amp;labelColor=161B3A&amp;style=flat-square"
    alt="build"></a>
  <a href="https://captf.io/docs/module-author/contract/index.html"><img
    src="https://img.shields.io/static/v1?label=contract&amp;message=v1alpha1&amp;color=A974FF&amp;labelColor=161B3A&amp;style=flat-square"
    alt="contract v1alpha1"></a>
  <a href="https://captf.io/docs/"><img
    src="https://img.shields.io/static/v1?label=docs&amp;message=captf.io&amp;color=5B8CFF&amp;labelColor=161B3A&amp;style=flat-square"
    alt="docs captf.io"></a>
  <a href="https://github.com/captf-io/terraform-oci-machinepool/blob/main/LICENSE.md"><img
    src="https://img.shields.io/static/v1?label=license&amp;message=Apache-2.0&amp;color=FFD84D&amp;labelColor=161B3A&amp;style=flat-square"
    alt="license Apache-2.0"></a>
</p>

> [!NOTE]
> **Pre-release.** CAPTF is `v1alpha1`: its API and its
> [module contract](https://captf.io/docs/module-author/contract/index.html)
> may still change between releases.

The CAPTF Oracle Cloud (OCI) machinepool module: the Terraform/OpenTofu root
module behind `TerraformMachinePool`, implementing the
[machinepool role](https://captf.io/docs/module-author/contract/v1alpha1/machinepool.html)
of the module contract. It creates one instance pool per
`TerraformMachinePool`, launched from an instance configuration and spread
over the MachinePool's failure domains, at a fixed size or sized by OCI
autoscaling.

The module image is `ghcr.io/captf-io/oci-machinepool`, published from
[oci-modules](https://github.com/captf-io/oci-modules). Design decisions are
in [DESIGN.md](https://github.com/captf-io/terraform-oci-machinepool/blob/main/DESIGN.md).

## Using it

CAPTF runs this module from the module image `ghcr.io/captf-io/oci-machinepool`:
set the image on a `TerraformMachinePool`'s `spec.source.image`, and the
controller renders every input. The module is also published to the Terraform
Registry as `captf-io/machinepool/oci` and can be called directly:

```hcl
module "machinepool" {
  source  = "captf-io/machinepool/oci"
  version = "~> 0.1"

  # The contract inputs the controller would render (captf_contract,
  # captf_cluster, captf_object, captf_tags, ...; see Inputs), and any
  # user variables.
}
```

Called directly, the module is a CAPTF root module first:

- it configures its own `provider "oci"` block, so the calling
  module cannot use `count`, `for_each` or `depends_on` on it, and the
  provider takes its credentials from the environment (see Identity
  Secret);
- its providers are pinned to exact versions (`versions.tf`), which the
  calling configuration has to accept;
- you set the `captf_*` inputs yourself.

## What it creates

| Resource | Address | When |
| --- | --- | --- |
| Instance configuration the pool launches from | `oci_core_instance_configuration.pool_instance_configuration` | always |
| Instance pool at `replicas` | `oci_core_instance_pool.fixed_instance_pool` | `autoscaling.enabled` false |
| Instance pool whose size the autoscaler owns | `oci_core_instance_pool.autoscaled_instance_pool` | `autoscaling.enabled` |
| Autoscaling configuration (CPU thresholds) | `oci_autoscaling_auto_scaling_configuration.pool_autoscaling_configuration` | `autoscaling.enabled` |
| Roll trigger on `kubernetes_version` | `terraform_data.kubernetes_version_roll` | always |

It reads the pool's members on every refresh.

The instances look like the machine role's workers: `image_id` on `shape`
(`VM.Standard.E5.Flex`, 2 OCPUs, 16 GB by default), a 100 GiB boot volume
encrypted at rest and in transit, the worker subnet and NSG, no public IP,
no SSH key, instance metadata v1 off, and the cluster's worker defined tag.

## Prerequisites

- A cluster made by the OCI cluster module, or `external_cluster_exports`.
- **An image** as for the machine role ([terraform-oci-machine README](https://github.com/captf-io/terraform-oci-machine/blob/main/README.md#prerequisites)),
  with cloud-init (node labels need it). With autoscaling, the image must run
  the Oracle Cloud Agent's Compute Instance Monitoring plugin: the
  autoscaler scales on its CPU metric.
- **The kubelet's provider ID**: `provider-id: oci://{{ v1.instance_id }}`
  in the `KubeadmConfig`'s `kubeletExtraArgs`, as in
  [`examples/cluster-kubeadm.yaml`](https://github.com/captf-io/terraform-oci-machinepool/blob/main/examples/cluster-kubeadm.yaml).
- **Quotas** for the pool's instances, and room for twice the pool during a
  Kubernetes version roll.
- **Permissions** of the identity's user:

  ```text
  Allow group <group> to manage instance-family in compartment <compartment>
  Allow group <group> to manage compute-management-family in compartment <compartment>
  Allow group <group> to manage auto-scaling-configurations in compartment <compartment>
  Allow group <group> to read metrics in compartment <compartment>
  Allow group <group> to use volume-family in compartment <compartment>
  Allow group <group> to use virtual-network-family in compartment <network compartment>
  # node_identity.defined_tag on the cluster:
  Allow group <group> to use tag-namespaces in tenancy
  ```

## Inputs

Contract inputs used: `captf_cluster` and `machinepool_name` (names),
`captf_cluster_outputs` (or `external_cluster_exports`), `captf_tags`,
`replicas`, `bootstrap_data`, `bootstrap_format`, `failure_domains`,
`cluster_failure_domains`, `kubernetes_version`, `node_labels`,
`autoscaling`. `captf_contract` is validated; `captf_object` is declared and
unused.

User variables (`spec.variables` on the `TerraformMachinePool`): those of the
[machine role](https://github.com/captf-io/terraform-oci-machine/blob/main/README.md#inputs) except that `subnet_id` defaults
to the worker subnet and `preemptible` has no control-plane check, plus:

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `autoscaling_scale_out_cpu_percent` | `number` | `70` | Add an instance above this CPU utilization. |
| `autoscaling_scale_in_cpu_percent` | `number` | `30` | Remove an instance below this CPU utilization. |
| `autoscaling_cool_down_seconds` | `number` | `300` | Minimum time between scaling actions (OCI's minimum). |
| `autoscaled` | `bool` | `false` | Must equal `autoscaling.enabled`: the deliberate second switch for a mode change, which replaces the pool. |

The full list: `additional_nsg_ids`, `additional_tags`, `autoscaled`,
`autoscaling_cool_down_seconds`, `autoscaling_scale_in_cpu_percent`,
`autoscaling_scale_out_cpu_percent`, `boot_volume_kms_key_id`,
`boot_volume_size_gib`, `external_cluster_exports`, `ignore_defined_tags`,
`image_id` (required), `memory_gib`, `ocpus`, `preemptible`, `public_ip`,
`pv_encryption_in_transit`, `shape`, `ssh_authorized_keys`, `subnet_id`.

## Outputs

| Name | Value |
| --- | --- |
| `provider_id` | OCID of the instance pool. |
| `provider_id_list` | `oci://<instance OCID>` of every member, whatever its health (an instance `TERMINATING` or `TERMINATED` is not a member), sorted: the cloud controller manager's format (see [terraform-oci-machine README](https://github.com/captf-io/terraform-oci-machine/blob/main/README.md#outputs)). |
| `replicas` | The pool's size as OCI reports it (`actual_size`, which the provider sets from the pool's `size` on every read): `replicas`, or what the autoscaler decided. Not the running count (`current_size`). |
| `instances` | Per member: `provider_id`, `instance_id`, `failure_domain` (mapped back from its availability and fault domain), `state` (the health enum), and `addresses = []`. |
| `health` | Below. |
| `dropped_node_labels` | `node_labels` keys left out because NodeRestriction forbids a kubelet to set them, sorted (not a contract output). |

## Exports

The machinepool role exports nothing; it reads the cluster's `exports`
([terraform-oci-cluster README](https://github.com/captf-io/terraform-oci-cluster/blob/main/README.md#exports)).

## Identity Secret

The cluster's identity, unless the `TerraformMachinePool` sets its own
`identityRef`. See the [oci-modules README](https://github.com/captf-io/oci-modules#using-it).

## Lifecycle

What updates in place and what rolls (machinepool.md "Lifecycle"):

| Change | Effect |
| --- | --- |
| `bootstrap_data` (a token rotation, about every 7.5 minutes with kubeadm), `node_labels`, image or any instance setting | A new instance configuration, created before the old one is deleted; the pool switches to it in place. Running instances stay; new ones get the new settings. |
| `kubernetes_version`, compared verbatim (a `+rke2rN` bump included) | The pool is replaced, new before old: a new pool comes up at the current size, then the old one and its instances go, and leave `provider_id_list`. `provider_id` changes. |
| `replicas`, autoscaling off | The pool is resized in place. |
| `replicas`, autoscaling on | Nothing: the autoscaler owns the size (`ignore_changes = [size]`). |
| `autoscaling.min`/`max` | The autoscaling configuration is replaced; the pool stays. |
| `autoscaling.enabled` on or off | Refused until `autoscaled` matches it; then the pool is replaced (it is a different resource), every instance at once. |
| `failure_domains` | The pool's placement is updated in place; existing instances stay where they are. |

## Bootstrap

A cloud-config payload becomes the second part of a MIME multipart
(`templates/user_data.mime.tftpl`):

1. a `text/cloud-boothook` part (`captf-boothook.sh`) that runs the shared
   node-labels fragment (`templates/node_labels.tftpl`, identical in every
   pool module, CONVENTIONS.md section 13) on every boot: for each of
   `/etc/default/kubelet` and `/etc/sysconfig/kubelet` whose directory
   exists, it replaces its own `# captf-node-labels` block with a
   `KUBELET_EXTRA_ARGS` line that keeps the image's value and appends
   `--node-labels=<labels>`, and it writes
   `/etc/rancher/rke2/config.yaml.d/50-captf-node-labels.yaml` with
   `node-label+:` for RKE2. Without labels it removes both;
2. the bootstrap payload unchanged, as a base64 part: `text/plain` (so
   cloud-init detects cloud-config and CABPK's Jinja header) or
   `application/x-gzip` for a gzipped payload, which cloud-init decompresses.

Pool instances have no Machine, so CAPI never labels their Nodes; this is
the only way `node_labels` reach them. Labels in the `kubernetes.io` and
`k8s.io` namespaces that a kubelet may not set on itself (NodeRestriction)
are dropped and listed in `dropped_node_labels`, such as
`node-role.kubernetes.io/worker`; `node.kubernetes.io/*`,
`kubelet.kubernetes.io/*` and the well-known topology labels stay.

An Ignition payload passes through unchanged; with node labels, or gzipped,
it fails a precondition.

## Tags

The pool, the instance configuration, the instances and their VNICs (through
the instance configuration) and the autoscaling configuration carry
`captf_tags` as free-form tags, `.` and space mapped to `_`
(`captf_io/cluster`), plus at most four `additional_tags`. Instances also
carry the cluster's worker defined tag, when it has one.

## Health

In this order (CONVENTIONS.md section 10):

| Situation | `health.state` | `healthy` | `reasons` |
| --- | --- | --- | --- |
| Pool gone from state (the provider drops a `TERMINATED` pool on read), or `TERMINATING`/`TERMINATED` | `terminated` | `false` | `PoolNotFound` |
| Desired size 0 | `running` | `true` | `[]` |
| No members yet | `pending` | `false` | `NoMembers` |
| A member degraded, stopped or unknown | the worst of those three | `false` | `<Reason>:<OCID>` per such member |
| Otherwise | `running` | only at the desired size with every member running | `ScalingInProgress` on a count mismatch, then `<Reason>:<OCID>` per starting member |

Members map like the machine role's instances: `PROVISIONING`, `STARTING`
pending (`InstanceProvisioning`, `InstanceStarting`); `RUNNING`, `MOVING`
running; `CREATING_IMAGE` unknown; `STOPPING`, `STOPPED` stopped; anything
else unknown (`UnknownState`). A `TERMINATING` or `TERMINATED` instance is
not a member. A starting member never makes the pool `pending`.

## Limitations

- **No drain.** A scale-in, a version roll or a mode switch terminates
  instances without draining them (MachinePool Machines are out of scope).
  OCI's pre-termination lifecycle action only delays termination; draining
  would still need an in-cluster handler, so it is not configured.
- **No addresses** in `instances`: the pool's member list carries none.
- **Autoscaling at zero** is rejected (`min` must be at least 1) until OCI
  threshold autoscaling down to zero is verified.
- **Existing members keep** their labels and bootstrap settings; only new
  members get a new instance configuration.
- **Bootstrap data size and secrecy** as for the machine role; the boothook
  part counts toward the 32,000-byte budget.

## Exceptions

- `tfcapi-lint` (module and image) warns `pool/autoscaling-ignore-changes`,
  allowed in the [Makefile](https://github.com/captf-io/terraform-oci-machinepool/blob/main/Makefile) (`TFCAPI_LINT_ALLOW`):
  the check knows desired-count attributes by name, and an OCI pool's is
  `size`, which it does not list. The autoscaled pool does ignore `size`;
  the unit test `autoscaling_keeps_observed_size` proves it.
- Switching autoscaling on or off replaces the pool and every instance in it
  (machinepool.md: modules SHOULD expose no replacing trigger besides
  `kubernetes_version`). OCI pools have no min/max to pin, so one pool
  resource cannot serve both modes (DESIGN.md decision 6). The `autoscaled`
  variable must be changed together with the annotations, so a mistyped
  annotation, which the controller renders as autoscaling off, fails the
  plan instead of replacing the pool.

## Examples

[`examples/cluster-kubeadm.yaml`](https://github.com/captf-io/terraform-oci-machinepool/blob/main/examples/cluster-kubeadm.yaml): a MachinePool of
three workers with a label, and the autoscaled variant through the
MachinePool's annotations:

```yaml
metadata:
  annotations:
    cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size: "2"
    cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size: "10"
```

with `autoscaled: true` in the `TerraformMachinePool`'s `spec.variables`.

## Developing

The host needs `make`, `podman` (or `docker` with `ENGINE=docker`), `jq` and
Go; every other tool runs in a container pinned by digest. `make verify` is
the gate. Override variables on the command line, for example
`make validate RUNTIMES=opentofu`.

| Target | What it does |
| --- | --- |
| `make fmt` | Format the module with `terraform fmt` and `tofu fmt`, in place. |
| `make fmt-check` | Fail on any file either formatter would change. |
| `make validate` | `init` and `validate` on both runtimes and on their floors (Terraform 1.5.7, OpenTofu 1.6.3). |
| `make unit-test` | `terraform test` and `tofu test` with mocked providers. |
| `make tflint` | `tflint` with the Terraform ruleset (preset all) and the cloud ruleset. |
| `make tfcapi-lint` | `tfcapi-lint module --strict`; skips when the linter is unavailable. |
| `make scan` | `trivy config` over the repository (HCL, workflows). |
| `make check-conventions` | `hack/check-layout.sh` (CONVENTIONS.md sections 2 and 4) and `hack/check-tags.sh` (section 7). |
| `make shellcheck` | `shellcheck` over `hack/` and every shell template, rendered with placeholders. |
| `make check-headers` | Fail on any source file without the Apache-2.0 license header. |
| `make fix-headers` | Add the license header to every source file missing it. |
| `make verify` | All of the above, in parallel groups: static checks, then one group per runtime. |
| `make clean` | Remove `build/`; keeps `.cache/` and `.tools/`. |

`tfcapi-lint` is built from the provider repository, found through
`PROVIDER_DIR` (default `../cluster-api-provider-terraform`). The repository
holds the code only: the module images are built and published from
[oci-modules](https://github.com/captf-io/oci-modules).

<br>
<p align="center">
  <img
    src="https://captf.io/assets/readme/divider.svg"
    width="100%" height="4" alt="">
</p>
<p align="center">
  <a href="https://captf.io/"><img
    src="https://captf.io/assets/readme/mark.svg"
    width="40" height="40" alt="CAPTF"></a>
  <br>
  <a href="https://captf.io/docs/"
    ><b>Documentation</b></a> ·
  <a href="https://captf.io/docs/getting-started/quick-start.html"
    ><b>Quick start</b></a> ·
  <a href="https://github.com/captf-io/.github/blob/main/CONTRIBUTING.md"
    ><b>Contributing</b></a> ·
  <a href="https://github.com/captf-io/.github/blob/main/SECURITY.md"
    ><b>Security</b></a>
  <br>
  <sub>Built for
    <a href="https://cluster-api.sigs.k8s.io/">Cluster API</a>.
    <a href="https://github.com/captf-io/terraform-oci-machinepool/blob/main/LICENSE.md"
    >Apache 2.0</a>.</sub>
</p>
