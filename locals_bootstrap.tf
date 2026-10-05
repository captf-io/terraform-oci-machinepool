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

# The instances' user data (CONVENTIONS.md section 13). Pool instances have no
# Machine, so CAPI never labels their Nodes: the module registers node_labels
# itself (machinepool.md "node_labels (input)"). A cloud-config payload goes
# in a MIME multipart: a boothook part with the shared node-labels fragment,
# then the bootstrap payload as an opaque base64 part, never decoded or
# parsed. Ignition passes through unchanged and takes no node labels.
locals {
  # Label keys the kubelet may set on its own Node; other kubernetes.io and
  # k8s.io keys fail kubelet startup and the NodeRestriction admission plugin
  # (IsKubeletLabel in
  # https://github.com/kubernetes/kubernetes/blob/v1.34.0/staging/src/k8s.io/kubelet/pkg/apis/well_known_labels.go).
  kubelet_labels = [
    "beta.kubernetes.io/arch",
    "beta.kubernetes.io/instance-type",
    "beta.kubernetes.io/os",
    "failure-domain.beta.kubernetes.io/region",
    "failure-domain.beta.kubernetes.io/zone",
    "kubernetes.io/arch",
    "kubernetes.io/hostname",
    "kubernetes.io/os",
    "node.kubernetes.io/instance-type",
    "topology.kubernetes.io/region",
    "topology.kubernetes.io/zone",
  ]
  kubelet_label_namespaces = ["kubelet.kubernetes.io", "node.kubernetes.io"]
  label_namespaces         = { for k in keys(var.node_labels) : k => length(split("/", k)) == 2 ? split("/", k)[0] : "" }
  restricted_labels = {
    for k, ns in local.label_namespaces : k => (
      (ns == "kubernetes.io" || endswith(ns, ".kubernetes.io") || ns == "k8s.io" || endswith(ns, ".k8s.io")) &&
      !contains(local.kubelet_labels, k) &&
      !anytrue([for allowed in local.kubelet_label_namespaces : ns == allowed || endswith(ns, ".${allowed}")])
    )
  }
  node_labels         = { for k, v in var.node_labels : k => v if !local.restricted_labels[k] }
  dropped_node_labels = sort([for k, restricted in local.restricted_labels : k if restricted])

  # "H4sI" is the base64 of the gzip magic bytes: CAPRKE2 gzipUserData.
  bootstrap_gzipped = nonsensitive(startswith(var.bootstrap_data, "H4sI"))

  # The shared node-labels fragment (templates/node_labels.tftpl, identical in
  # every pool module), sorted and comma-joined. It runs even without labels:
  # then it removes what an earlier boot wrote.
  node_labels_script = templatefile("${path.module}/templates/node_labels.tftpl", {
    node_labels = join(",", [for k in sort(keys(local.node_labels)) : "${k}=${local.node_labels[k]}"])
  })
  boothook = templatefile("${path.module}/templates/boothook.sh.tftpl", {
    node_labels_script = local.node_labels_script
  })

  # cloud-config payloads are wrapped in a MIME multipart: the boothook,
  # then the payload as an opaque base64 part that is never decoded here.
  # text/plain makes cloud-init detect the payload's type itself, which
  # keeps CABPK's "## template: jinja" header working; application/x-gzip
  # makes it decompress first (_process_msg in cloudinit/user_data.py).
  # Ignition has no such envelope and passes through unchanged, without
  # node labels.
  user_data_mime = templatefile("${path.module}/templates/user_data.mime.tftpl", {
    boothook             = local.boothook
    boundary             = "==CAPTF-BOUNDARY=="
    payload_base64       = join("\n", regexall(".{1,76}", var.bootstrap_data))
    payload_content_type = local.bootstrap_gzipped ? "application/x-gzip" : "text/plain; charset=\"utf-8\""
  })
  user_data = var.bootstrap_format == "cloud-config" ? base64encode(local.user_data_mime) : var.bootstrap_data

  metadata = merge(
    { user_data = local.user_data },
    length(var.ssh_authorized_keys) == 0 ? {} : { ssh_authorized_keys = join("\n", var.ssh_authorized_keys) },
  )
  # metadata and extended_metadata together may hold 32,000 bytes:
  # https://docs.oracle.com/en-us/iaas/api/#/en/iaas/latest/LaunchInstanceDetails
  metadata_limit_bytes = 32000
  # The size of what is sent is not secret, only the payload is.
  metadata_bytes = nonsensitive(length(jsonencode(local.metadata)))
}
