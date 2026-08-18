# Plan: stop treating node01 as a general-purpose scheduling target

**Status:** designed, partially staged in git, **not applied to the cluster**.
**Date:** 2026-08-17
**Related:** `docs/incidents/2026-07-19-dojo-runner-node01-instability.md`

## Problem

node01 is the cluster's sole k3s control-plane node (8 GiB RAM, embedded SQLite
datastore, apiserver/scheduler/controller-manager) and carries **no taint at
all**. k3s — unlike kubeadm — does not taint the server node by default, and
`ansible/playbooks/04-install-k3s.yml` never passed `--node-taint`. There is no
comment, variable, or commit message anywhere in this repo indicating the
absence was deliberate; it is the k3s default, inherited unexamined.

The result: node01 is a fully general-purpose worker. It currently runs **58 of
the cluster's 99 running pods**, including things with no reason to be there —
all 3 Rancher replicas, both LAN-DNS CoreDNS replicas, a GitHub Actions runner.

## What tainting node01 does and does not fix

This must be stated plainly, because it is easy to overclaim.

**It does fix:** arbitrary new workload landing on the control-plane node. That
is the recurring class of problem — the GitHub Actions runner replica, the
Rancher stack, the CoreDNS collapse. Each was an independent accident of the
same missing constraint.

**It does not fix** the root cause documented in the 2026-07-19 incident. That
investigation concluded the cascade is **disk I/O co-location** — node01's
embedded SQLite datastore shares one NVMe with ~20 Longhorn volume replicas, and
Longhorn I/O starves SQLite writes until apiserver P99 write latency hits 4.77s
and every node's kubelet lease expires at once. A `NoSchedule` taint does not
move Longhorn replicas (Longhorn schedules those itself, independent of k8s
taints) and does not move the datastore. Load1 peaks of 236 on an 8-core node
with sub-1-core container CPU are I/O queueing, not memory or CPU pressure.

**It also does not fix cluster DNS.** See "Two CoreDNS instances" below.

The two fixes that do target the root cause remain the incident doc's: a
dedicated disk/partition for `/var/lib/rancher/k3s/server/db`, or an HA
control plane. Neither is in scope here.

## Two CoreDNS instances — only one is ours, and it is not cluster DNS

|              | `coredns/coredns`                                          | `kube-system/coredns`                                            |
| ------------ | ---------------------------------------------------------- | ---------------------------------------------------------------- |
| Purpose      | LAN DNS for `*.homelab.local`, MetalLB LB IP 192.168.87.13 | **cluster DNS** (10.43.0.10), what every pod resolves against    |
| Replicas     | 2                                                          | **1**                                                            |
| Managed by   | this repo, `kubernetes/apps/coredns/`                      | k3s built-in addon manifest                                      |
| Spread rules | none (both on node01)                                      | `maxSkew: 1` / `DoNotSchedule` already present                   |
| Tolerations  | none                                                       | **tolerates `node-role.kubernetes.io/control-plane:NoSchedule`** |

Consequences:

1. Tainting node01 moves the **LAN DNS** pair off it. Good, but that is not the
   DNS the cluster depends on.
2. Tainting node01 **does not move cluster DNS** — `kube-system/coredns`
   tolerates the taint and will stay exactly where it is, on the most
   I/O-starved node in the cluster, at 1 replica, currently showing **494
   restarts**.
3. Its existing topology spread constraint is inert at 1 replica.

So the single highest-value DNS fix is unchanged from the incident doc's third
recommendation, still unapplied: **scale `kube-system/coredns` to 2 replicas.**
Its spread constraint then does the rest automatically. This is cheap and
low-risk, and it is independent of the taint work.

That deployment is a k3s built-in, applied from
`/var/lib/rancher/k3s/server/manifests/coredns.yaml` on the node. `kubectl scale`
works immediately but is reverted whenever k3s re-applies the packaged manifest
(upgrade or restart). The durable options are (a) `--disable coredns` and adopt
CoreDNS into `kubernetes/apps/` as GitOps-managed, or (b) ship a customised
manifest into that directory via ansible. Both are node-level changes outside
this repo's current ArgoCD surface.

## Blocker: Longhorn must be handled before the taint

This is the one step that can cause real data-availability harm, and it gates
everything else.

- Longhorn's three DaemonSets (`longhorn-manager`, `longhorn-csi-plugin`,
  `engine-image-ei-*`) have **`tolerations: null`** — they tolerate nothing.
- Longhorn's global `taint-toleration` setting is **empty**.
- node01 hosts **20 of the cluster's 78 Longhorn volume replicas**, and 24
  volumes are currently attached.

`NoSchedule` does not evict running pods, so tainting alone causes no immediate
outage. But the moment anything restarts those pods — a k3s restart, a node
reboot, a Longhorn upgrade — they go `Pending`, node01 goes `Down` in Longhorn,
and 20 replicas degrade and rebuild across the remaining nodes. If the taint is
applied _via a k3s restart_, that trigger fires immediately.

Longhorn v1.5.3 requires **all volumes detached** before the `taint-toleration`
setting is applied to system-managed components. That means stopping every
stateful workload (media stack, Gitea, Home Assistant, investment-bot) for the
duration — a real maintenance window, not an incidental step.

Two viable orderings:

- **Preferred — evict node01 as a Longhorn storage node first.** Disable
  scheduling on node01 in Longhorn and let it drain its 20 replicas to the other
  three nodes. This is Longhorn-native, needs no k8s changes, no taint, and no
  volume detach — and it _directly attacks the documented root cause_ by taking
  Longhorn I/O off the disk holding the SQLite datastore. Do this first and
  measure; it may resolve the cascade on its own, making the rest lower-stakes.
- **Alternative — set Longhorn's `taint-toleration`** to
  `node-role.kubernetes.io/control-plane=true:NoSchedule` during a full
  volumes-detached window, keeping node01 as a storage node. Heavier, and it
  preserves the exact disk contention the incident blamed.

## How the taint gets applied — and why it is not GitOps

A node taint is not expressible as a manifest in `kubernetes/`, so ArgoCD cannot
own it. Three mechanisms, with tradeoffs:

1. **Imperative `kubectl taint`** — takes effect instantly, no restart, trivially
   reversible. Persists across k3s restarts (it lives in the Node object), but is
   lost on a node rebuild/re-registration and is tracked nowhere.
2. **`/etc/rancher/k3s/config.yaml` + k3s restart** — durable across
   re-registration, but restarting the sole apiserver causes a brief control-plane
   outage and restarts every pod on node01, which is precisely the Longhorn
   trigger described above. Do not choose this before Longhorn is handled.
3. **The ansible playbook** — `04-install-k3s.yml` now carries
   `--node-taint=node-role.kubernetes.io/control-plane=true:NoSchedule`, but
   `--node-taint` applies only at _first registration_. This makes a rebuilt
   cluster reproduce the taint; **it does nothing to the running cluster**, and
   re-running that playbook would reinstall k3s.

Recommendation: option 1 for the running cluster (reversible in one command),
with option 3 already staged so a rebuild does not silently regress. Option 2 is
the "correct" config-as-code answer but is not worth an apiserver restart here.

## node01 pod inventory — what moves, what stays

**Stays (already tolerates `control-plane:NoSchedule`), 6 pods:**
`kube-system/coredns`, `kube-system/traefik`, `kube-system/metrics-server`,
`kube-system/local-path-provisioner`, `metallb-system/speaker` (DaemonSet),
`monitoring/…prometheus-node-exporter` (DaemonSet, tolerates everything).
No manifest changes needed for any of these.

**Must stay but does NOT tolerate — the blocker, 4 pods:**
`longhorn-system/longhorn-manager`, `longhorn-csi-plugin`,
`engine-image-ei-68f17757`, `instance-manager-*`. Handled per the Longhorn
section above, not by editing manifests (Longhorn's manager reverts hand-edited
DaemonSets; the global setting is the supported path).

**Moves away — general workload that landed there by scheduler accident, ~47
pods:** the 7 ArgoCD components, 3 Rancher replicas + rancher-webhook +
system-upgrade-controller, fleet-controller, gitjob, capi-controller-manager,
3 cert-manager components, both LAN CoreDNS replicas, 2 homepage pods, the 12
Longhorn CSI sidecar Deployments (attacher/provisioner/resizer/snapshotter ×3)
plus driver-deployer and 2 longhorn-ui, metallb controller, sealed-secrets
controller, authelia, and 8 monitoring exporters/operator/kube-state-metrics.
None of these are node-local; all are safe to relocate.

Note that `NoSchedule` does not evict them. They move only as they are naturally
recreated (deployment rollout, pod delete, node reboot), so the migration is
gradual rather than a thundering herd — which is desirable here.

## Capacity check — the other nodes can absorb it

Measured usage at 2026-08-17:

| Node   | Allocatable | In use         | Free     | Mem requests | Mem limits |
| ------ | ----------- | -------------- | -------- | ------------ | ---------- |
| node01 | 7.5 GiB     | 5594 Mi (72%)  | ~1.9 GiB | 22%          | 70%        |
| node02 | 31.0 GiB    | 10263 Mi (32%) | ~21 GiB  | 15%          | 62%        |
| node03 | 7.5 GiB     | 2924 Mi (38%)  | ~4.8 GiB | 39%          | **159%**   |
| node04 | 15.3 GiB    | 5586 Mi (35%)  | ~9.7 GiB | 18%          | 65%        |

node01's pods sum to ~2550 Mi; subtracting what stays (~161 Mi) and the Longhorn
node-local set (~583 Mi) leaves **~1.8 GiB to relocate**. node02 alone has ~21
GiB free and absorbs all of it comfortably; node04 adds ~9.7 GiB of slack.

**node03 should not receive this load.** It has the least free memory of the
three workers, its memory limits are already 159% oversubscribed, and per
`ansible/inventory/hosts.yml` it is the media-storage node (`/dev/sda`,
`/dev/sdb`). The light-runner fix deliberately steered away from it for the same
reason. No hard exclusion is staged — the default scheduler scores by requests
and will favour node02 — but if anything material does land on node03 after the
taint, add a soft `preferredDuringScheduling` anti-affinity rather than a hard
rule, so node03 stays available as a fallback.

The ~2.4 GiB gap between node01's pod sum (2550 Mi) and its actual usage (5594
Mi) is the k3s server process itself — apiserver, scheduler, controller-manager
and the SQLite datastore run outside the pod accounting. Freeing 1.8 GiB of pod
memory therefore leaves node01 at roughly 3.8 GiB of 7.5 GiB, which is real
headroom, but it does not touch the I/O bottleneck.

## What is staged in this repo

- `kubernetes/apps/coredns/deployment.yaml` — `topologySpreadConstraints`
  (`maxSkew: 1`, `kubernetes.io/hostname`, `DoNotSchedule`,
  `nodeTaintsPolicy: Honor`) so the two LAN-DNS replicas cannot re-collapse onto
  one node. This is the only part of the whole plan that is genuinely
  GitOps-managed here.
- `ansible/playbooks/04-install-k3s.yml` — `--node-taint` on the server install,
  for rebuild reproducibility only.

**Not staged, because this repo does not own them:**

- The node01 taint itself (node-level, see above).
- `kube-system/coredns` replica count (k3s built-in addon).
- Rancher's scheduling. `kubernetes/apps/rancher/` contains only `namespace.yaml`
  and `ingress-fixed.yaml` — the Deployment is Helm-installed out of band. Its 3
  replicas share one soft `preferredDuringSchedulingIgnoredDuringExecution`
  podAntiAffinity (weight 100), which is why all three sit on node01: a
  preference the scheduler was free to ignore, and did. Fixing it means a
  `helm upgrade` with a values override promoting that to
  `requiredDuringSchedulingIgnoredDuringExecution`, or adopting the Deployment
  into this repo. A kustomize patch here cannot reach a resource ArgoCD does not
  render.
- Longhorn's `taint-toleration` (Longhorn CRD setting).

## Rollout order

ArgoCD is `automated` with `prune: true` and `selfHeal: true` on
`targetRevision: HEAD` — **pushing to main is the deploy.** There is no separate
apply step for the CoreDNS change.

1. **Scale `kube-system/coredns` to 2 replicas first.** Independent of
   everything else, immediately improves the situation, and means cluster DNS
   already has redundancy before anything starts moving. Verify two Ready pods on
   two distinct nodes.
2. **Push the CoreDNS spread constraint.** Watch ArgoCD sync `homelab-apps`.
   Confirm both `coredns/coredns` pods go Ready on two distinct nodes and the
   MetalLB LB IP 192.168.87.13 still answers. If a replica sits `Pending`, the
   constraint is too strict for the available node count — revert the commit.
3. **Drain node01 as a Longhorn storage node** and wait for all 20 replicas to
   rebuild elsewhere and every volume to report `Healthy`. Do not proceed while
   any volume is `Degraded`. Re-measure the apiserver write-latency and load1
   symptoms here — this step alone may resolve the cascade.
4. **Only then, taint node01**, imperatively and reversibly:
   ```
   kubectl taint nodes node01 node-role.kubernetes.io/control-plane=true:NoSchedule
   ```
5. **Let migration happen gradually.** `NoSchedule` does not evict. Resist
   mass-deleting pods to force the move; every natural rollout relocates another
   workload. If something must move now, delete that one pod.
6. **Rancher last**, as a separate deliberate change, once everything above is
   stable.

## What to watch

- **Cluster DNS** — the loudest failure mode. Resolve an in-cluster name from a
  pod on a node other than node01 before and after each step.
- **LAN DNS** — 192.168.87.13 must keep answering `*.homelab.local`; a failure
  here breaks every ingress hostname on the household network.
- **Longhorn volume health** — all volumes `Healthy`, no `Degraded`, during and
  after step 3.
- **Rancher UI** at rancher.homelab.local, and ArgoCD at argocd.homelab.local —
  both currently run entirely on node01 and will relocate.
- **Pending pods** — `kubectl get pods -A --field-selector status.phase=Pending`
  should stay empty. Anything stuck Pending means a constraint is unsatisfiable.
- **node01 restart counts** — Rancher pods are at 700+, `kube-system/coredns` at 494. These should stop climbing if the change helps.

## Rollback

Every step is independently reversible, in increasing order of effort:

- **Taint (step 4)** — remove it, immediately:
  ```
  kubectl taint nodes node01 node-role.kubernetes.io/control-plane=true:NoSchedule-
  ```
  Pending pods schedule again within seconds. This is the fastest lever; pull it
  first if anything looks wrong.
- **CoreDNS spread constraint (step 2)** — `git revert` the commit; ArgoCD
  self-heals back within its sync interval.
- **Longhorn drain (step 3)** — re-enable scheduling on node01 in Longhorn.
  Replicas do not automatically move back, but nothing is lost; node01 simply
  becomes eligible again.
- **Ansible playbook change** — inert on the running cluster; nothing to roll
  back.
