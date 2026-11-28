# Upgrading k3s on the Pi 5 (v1.33.3 to v1.34.13)

Traefik on this cluster is the copy bundled with k3s, so it moves when k3s moves. There is no
`HelmChartConfig` and no separate image pin. This page is the plan for moving the Pi 5 from
`v1.33.3+k3s1` to `v1.34.13+k3s1`, which raises bundled Traefik from 3.3.6 to 3.7.15 (the
CVE floor is 3.7.13).

`ansible/playbooks/k3s-install.yml` now pins `k3s_version: v1.34.13+k3s1`, but its install task
only runs when `/usr/local/bin/k3s` is missing. Re-running the playbook on the existing node does
**not** upgrade it; it only sets the version for a fresh install. The upgrade itself is the manual
steps below, run on the Pi.

## Candidate releases

Chart and image versions are read from `manifests/traefik.yaml` and
`scripts/airgap/image-list.txt` at each tag.

| k3s | Kubernetes minor | Traefik chart | Traefik image | Meets 3.7.13? |
|---|---|---|---|---|
| [v1.33.3+k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.33.3%2Bk3s1) (running) | 1.33 | 34.2.1+up34.2.0 | 3.3.6 | no |
| [v1.33.13+k3s2](https://github.com/k3s-io/k3s/releases/tag/v1.33.13%2Bk3s2) (last 1.33) | 1.33 | 40.1.4+up40.1.0 | 3.7.8 | no |
| [v1.34.11+k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.34.11%2Bk3s1) | 1.34 | 40.1.4+up40.1.0 | 3.7.8 | no |
| [v1.34.12+k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.34.12%2Bk3s1) | 1.34 | 40.1.5+up40.1.0 | 3.7.13 | yes (floor) |
| [v1.34.13+k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.34.13%2Bk3s1) (target) | 1.34 | 40.1.7+up40.1.0 | 3.7.15 | yes |
| [v1.35.10+k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.35.10%2Bk3s1) | 1.35 | 40.1.7+up40.1.0 | 3.7.15 | yes, two minors away |
| [v1.37.2+k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.37.2%2Bk3s1) | 1.37 | 41.6.101+up41.6.1 | 3.7.15 | yes, four minors away |

No 1.33 release reaches 3.7.13, so the smallest upgrade that does is one minor step to 1.34.
`v1.34.13+k3s1` is the newest 1.34 patch and carries the same Traefik as 1.35 and 1.36, so going
further buys nothing for Traefik.

## Upgrade order

k3s follows the Kubernetes skew policy: do not skip a minor version, and upgrade servers one at a
time before agents ([k3s manual upgrades](https://docs.k3s.io/upgrades/manual)). This cluster is one
server node with no agents, so the order is a single step:

1. Optional: `v1.33.3+k3s1` to `v1.33.13+k3s2`. This moves Traefik to chart 40 / 3.7.8 while
   Kubernetes stays on 1.33, so a Traefik problem shows up apart from the Kubernetes minor change.
2. `v1.33.x` to `v1.34.13+k3s1`.

Run the pre-checks before each step and the post-checks after it.

## Pre-checks

```bash
export KUBECONFIG=~/.kube/config-raspberrypi-5

ssh <pi> 'k3s --version'
kubectl get nodes -o wide
kubectl -n kube-system get deploy traefik \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

# The repo has no HelmChartConfig. Anything listed here was added by hand and must be
# checked against the chart 40 value renames before upgrading.
kubectl get helmchartconfigs.helm.cattle.io -A

# Traefik CRD objects that the 3.7 CRD update would touch (the repo uses none).
kubectl get ingressroutes.traefik.io,middlewares.traefik.io -A

kubectl get ingress -A
kubectl get pods -A | grep -v -E 'Running|Completed'

ssh <pi> 'df -h /var/lib/rancher'
```

The datastore is SQLite: the k3s config sets no `cluster-init` and no `datastore-endpoint`.
Confirm, then snapshot it with k3s stopped:

```bash
ssh <pi> 'sudo ls /var/lib/rancher/k3s/server/db/'   # state.db*, and no etcd/ directory
ssh <pi> 'sudo systemctl stop k3s \
  && sudo cp -a /var/lib/rancher/k3s/server/db /var/lib/rancher/k3s/server/db.pre-v1.34 \
  && sudo cp -a /var/lib/rancher/k3s/server/token /var/lib/rancher/k3s/server/token.pre-v1.34 \
  && sudo systemctl start k3s'
```

Stopping the k3s service leaves running pods alone. Pi-hole and Home Assistant run in Docker and
are not affected by any of this.

## Upgrade step

Re-run the install script with the same environment and arguments the playbook used; the script
drops any it is not given ([k3s manual upgrades](https://docs.k3s.io/upgrades/manual)). The server
options in `/etc/rancher/k3s/config.yaml` (TLS SANs) are untouched by the script.

```bash
ssh <pi>
curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
sudo INSTALL_K3S_VERSION=v1.34.13+k3s1 \
  K3S_NODE_NAME=raspberrypi-5 \
  K3S_KUBECONFIG_MODE=644 \
  sh /tmp/k3s-install.sh --write-kubeconfig-mode=644
```

The kubeconfig on the Mac keeps working: the CA and the API certificate do not change.

## Breaking changes that touch this repo

Kubernetes 1.33 to 1.34:

- No API version is removed in 1.33 or 1.34; the last removal was
  `flowcontrol.apiserver.k8s.io/v1beta3` in 1.32
  ([deprecation guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)).
  Everything here uses `networking.k8s.io/v1`, `v1` core and `monitoring.coreos.com/v1`.
- `v1` Endpoints is deprecated in favour of EndpointSlice since 1.33. `modules/homepage-ingress`
  creates a selector-less Service with a hand-written `kubernetes_endpoints`; it still works, and
  the EndpointSlice mirroring controller copies it into a slice. Expect deprecation warnings from
  Terraform, not failures.

k3s 1.33 to 1.34 ([v1.34.1+k3s1 notes](https://github.com/k3s-io/k3s/releases/tag/v1.34.1%2Bk3s1)):

- Tolerations for the old `node-role.kubernetes.io/master` taint are removed from packaged
  manifests. The node does not carry that taint, so nothing changes here.
- containerd moves from 2.0 to 2.2 (2.2.10 in
  [v1.34.13+k3s1](https://github.com/k3s-io/k3s/releases/tag/v1.34.13%2Bk3s1)).

Traefik chart 34 to 40 ([v40.0.0](https://github.com/traefik/traefik-helm-chart/releases/tag/v40.0.0)):

- `providers.kubernetesIngressNginx` is renamed `providers.kubernetesIngressNGINX`, and the
  `service` values follow Kubernetes syntax. Both only matter to a `HelmChartConfig`, and the repo
  has none (see the pre-check).
- The 3.7 CRDs change. k3s applies them through the `helm-install-traefik-crd` job.

Traefik 3.3 to 3.7.15 ([v3 migration notes](https://doc.traefik.io/traefik/migrate/v3/)):

- The Kubernetes Ingress provider still honours the `kubernetes.io/ingress.class: traefik`
  annotation used by `modules/homepage-ingress`; with `ingressClass` unset it processes Ingresses
  whose annotation is `traefik`
  ([Ingress provider options](https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-ingress/)).
- 3.4.1 normalises request paths and 3.6.4 / 3.6.7 change how encoded characters in paths are
  handled. The homepage Ingress is a single `/` Prefix rule, so routing does not change.
- 3.7.13 stops forwarding `Upgrade: h2c` and rejects rootless request targets with 400; 3.7.15
  answers every `CONNECT` with 501. Nothing here relies on h2c or CONNECT.
- `configs/traefik/traefik.yaml` is a Docker-provider Traefik config that no module wires up. It is
  not the k3s Traefik and the upgrade does not touch it.

## Post-checks

```bash
ssh <pi> 'k3s --version'                     # v1.34.13+k3s1
kubectl get nodes                            # Ready, VERSION v1.34.13+k3s1

kubectl -n kube-system get deploy traefik \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
# ends in rancher/mirrored-library-traefik:3.7.15
kubectl -n kube-system get helmchart traefik -o jsonpath='{.spec.chart}{"\n"}'
# ends in traefik-40.1.7+up40.1.0.tgz

kubectl -n kube-system get jobs | grep helm-install-traefik
kubectl -n kube-system logs job/helm-install-traefik-crd --tail=50
kubectl -n kube-system logs job/helm-install-traefik --tail=50
kubectl -n kube-system rollout status deploy/traefik
kubectl -n kube-system logs deploy/traefik --tail=100 | grep -iE 'error|warn'

kubectl -n homepage-ingress get ingress,endpointslices
curl -sI -H 'Host: raspberrypi-5' http://<pi>/ | head -1

kubectl get pods -n monitoring
kubectl get pods -A | grep -v -E 'Running|Completed'
terraform plan    # expect no changes beyond the Endpoints deprecation warning
```

When every check passes and the cluster has run cleanly for a while, delete
`db.pre-v1.34` and `token.pre-v1.34`.

## Rollback

k3s can only go back to an earlier minor with a datastore snapshot taken on that minor; without one
there is no rollback ([k3s rollback](https://docs.k3s.io/upgrades/roll-back)). For SQLite the
snapshot is the copy taken in the pre-checks.

```bash
ssh <pi>
sudo /usr/local/bin/k3s-killall.sh
curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
sudo INSTALL_K3S_VERSION=v1.33.3+k3s1 INSTALL_K3S_SKIP_START=true \
  K3S_NODE_NAME=raspberrypi-5 \
  K3S_KUBECONFIG_MODE=644 \
  sh /tmp/k3s-install.sh --write-kubeconfig-mode=644
sudo rm -rf /var/lib/rancher/k3s/server/db
sudo cp -a /var/lib/rancher/k3s/server/db.pre-v1.34 /var/lib/rancher/k3s/server/db
sudo cp -a /var/lib/rancher/k3s/server/token.pre-v1.34 /var/lib/rancher/k3s/server/token
sudo systemctl start k3s
k3s --version && sudo k3s kubectl get nodes
```

`k3s-killall.sh` stops every pod, so the monitoring stack and the homepage Ingress are down until
k3s is back. Set `k3s_version` in the playbook back to `v1.33.3+k3s1` if you roll back.
A rollback within the same minor (for example from `v1.33.13+k3s2` to `v1.33.3+k3s1`) needs only
the reinstall, not the restore.
