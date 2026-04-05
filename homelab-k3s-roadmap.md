# Homelab k3s Learning Roadmap

## Pi Cluster: mou-pi5 (control plane) + mou-pi4 (worker)

---

## Cluster Hardware


| Node    | Model          | Role          | Boot    | Root      | RAM |
| ------- | -------------- | ------------- | ------- | --------- | --- |
| mou-pi5 | Raspberry Pi 5 | Control plane | SD card | USB drive | 2GB |
| mou-pi4 | Raspberry Pi 4 | Worker        | SD card | USB drive | 1GB |


### Planned USB Drive Layout (32GB each)


| Partition | Size | Mount Point       | Purpose                       |
| --------- | ---- | ----------------- | ----------------------------- |
| sda1      | 20GB | /var/lib/rancher  | k3s + etcd + container images |
| sda2      | 12GB | /var/lib/longhorn | Persistent storage            |


---

## Phase 1 — k3s Cluster Bootstrap

**Goal:** Get a working 2-node cluster up and running.

### Steps

1. Partition USB drives on both nodes
2. Install k3s server on mou-pi5
3. Install k3s agent on mou-pi4 and join cluster
4. Verify both nodes show Ready

### Commands

```bash
# Prep for k3s install by setting cgroup params
sudo sed -i '$ s/$/ cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt
## ******* RESTART AFTER THIS CHANGE *******

# On mou-pi5 — install control plane
curl -sfL https://get.k3s.io | sh -

# Generate command to run on nodes
cat << EOF
curl -sfL https://get.k3s.io | \\
  K3S_URL=https://$(hostname -I | awk '{print $1}'):6443 \\
  K3S_TOKEN="$(sudo cat /var/lib/rancher/k3s/server/node-token)" \\
  sh -
EOF

# On mou-pi4 — join as worker by running the command output above
curl -sfL https://get.k3s.io | \
  K3S_URL=https://<HOST>:6443 \
  K3S_TOKEN="<TOKEN>" \
  sh -

# Verify
kubectl get nodes
```

#### Fix — Tell k3s to bind to the network IP


##### Create config file
```shell
# Create k3s config directory
sudo mkdir -p /etc/rancher/k3s

sudo tee /etc/rancher/k3s/config.yaml <<EOF
tls-san:
  - mou-pi5.local
  - mou-pi5.oue.home
  - 192.168.5.152
bind-address: 0.0.0.0
EOF
```

##### Restart k3s
```shell
sudo systemctl restart k3s
```


### Key Concepts

- Control plane vs worker node roles
- etcd — the cluster database
- kubeconfig — how kubectl authenticates
- Namespaces — logical cluster isolation

---

## Phase 2 — First Deployments + Helm

**Goal:** Deploy real apps, learn Helm package manager.

### Steps

1. Deploy a simple app (nginx or a self-hosted dashboard)
2. Install Helm
3. Deploy an app via Helm chart
4. Understand Deployments, Services, Pods

### Commands

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Deploy nginx
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=ClusterIP

# Check it
kubectl get pods
kubectl get services
```

### Key Concepts

- Pods, Deployments, ReplicaSets
- Services (ClusterIP, NodePort, LoadBalancer)
- Helm charts, values.yaml, releases
- kubectl basics (get, describe, logs, exec)

---

## Phase 3 — Ingress + TLS

**Goal:** Route external traffic into the cluster with HTTPS.

k3s ships with **Traefik** as the ingress controller — no install needed.

### Steps

1. Create an Ingress resource for a deployed app
2. Install cert-manager
3. Configure Let's Encrypt (or self-signed for homelab)
4. Enable automatic TLS on ingress

### Commands

```bash
# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### Key Concepts

- Ingress controllers (Traefik)
- Ingress resources and routing rules
- cert-manager and Certificate resources
- ClusterIssuer vs Issuer
- TLS termination

---

## Phase 4 — Observability (Prometheus + Grafana)

**Goal:** Monitor the cluster and nodes including Pi-specific metrics.

### Steps

1. Install kube-prometheus-stack via Helm
2. Set up Grafana dashboards
3. Add vcgencmd metrics (temp, voltage, throttling) from both Pis
4. Set up basic alerting

### Commands

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### Pi-specific Metrics to Capture

```bash
# These vcgencmd values are worth exposing to Prometheus:
vcgencmd measure_temp         # CPU temperature
vcgencmd measure_volts core   # Core voltage
vcgencmd get_throttled        # Throttling/undervoltage status
vcgencmd measure_clock arm    # CPU clock speed
```

### Key Concepts

- Prometheus scraping and metrics format
- PromQL query language
- Grafana dashboards and panels
- Alertmanager
- node_exporter for host metrics
- ServiceMonitor CRDs

---

## Phase 5 — Persistent Storage

**Goal:** Give pods storage that survives restarts and node failures.

### Step 5a — Start with local-path (k3s default)

Already installed with k3s. Good for getting started.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes: [ "ReadWriteOnce" ]
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

### Step 5b — Install Longhorn

Distributed block storage with built-in UI and replication.

```bash
helm repo add longhorn https://charts.longhorn.io
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --set defaultSettings.defaultDataPath=/var/lib/longhorn
```

### Step 5c — Try OpenEBS (compare with Longhorn)

Multiple storage engines — try Jiva for Pi (lightweight).

```bash
helm repo add openebs https://openebs.github.io/charts
helm install openebs openebs/openebs \
  --namespace openebs \
  --create-namespace
```

### Key Concepts

- PersistentVolume (PV) and PersistentVolumeClaim (PVC)
- StorageClass and dynamic provisioning
- ReadWriteOnce vs ReadWriteMany access modes
- Longhorn volume replication
- CSI (Container Storage Interface) drivers

---

## Phase 6 — GitOps with ArgoCD

**Goal:** Manage all cluster config from Git. Highly in-demand skill.

### Steps

1. Install ArgoCD
2. Connect a Git repo
3. Deploy an app via ArgoCD (not kubectl)
4. Make a change in Git and watch ArgoCD sync it

### Commands

```bash
# Install ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### Key Concepts

- GitOps principles — Git as single source of truth
- ArgoCD Applications and AppProjects
- Sync policies (manual vs automatic)
- Helm + ArgoCD integration
- Kustomize as an alternative to Helm
- Drift detection and self-healing

---

## Phase 7 — Backup + DR with Velero + MinIO

**Goal:** Backup cluster state and persistent volumes to S3-compatible storage.

### Steps

1. Deploy MinIO on the cluster (self-hosted S3)
2. Install Velero pointing at MinIO
3. Take a backup of a namespace
4. Simulate disaster — delete the namespace
5. Restore from backup

### Commands

```bash
# Install MinIO
helm repo add minio https://charts.min.io
helm install minio minio/minio \
  --namespace minio \
  --create-namespace

# Install Velero
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.backupStorageLocation[0].provider=aws \
  --set configuration.backupStorageLocation[0].bucket=velero \
  --set configuration.backupStorageLocation[0].config.s3Url=http://minio:9000
```

### Key Concepts

- MinIO as S3-compatible object store
- Velero backup/restore workflow
- Disaster recovery planning
- RPO and RTO concepts
- Backup schedules and retention

---

## Phase 8 — Expand the Cluster

**Goal:** Add Linux desktop as a 3rd node for HA and more storage.

### Steps

1. Install k3s agent on Linux desktop
2. Join as worker node
3. Label/taint nodes for workload placement
4. Enable Longhorn replication across 3 nodes
5. Test node failure scenarios

### Requirements for Desktop Node

```bash
# Install open-iscsi (required for Longhorn)
sudo apt install open-iscsi -y
sudo systemctl enable iscsid
sudo systemctl start iscsid
```

### Key Concepts

- Node labels and selectors
- Taints and tolerations
- Pod affinity and anti-affinity
- HA control plane (requires 3 control plane nodes)
- Longhorn replica scheduling

---

## Phase 9 — Service Mesh with Linkerd

**Goal:** Add mTLS, observability, and traffic management between services.

Linkerd recommended over Istio for Pi — much lighter resource usage.

### Steps

1. Install Linkerd CLI
2. Install Linkerd control plane
3. Inject Linkerd proxy into existing deployments
4. Explore traffic metrics in Linkerd dashboard

### Commands

```bash
# Install Linkerd CLI
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh

# Install control plane
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -

# Verify
linkerd check
```

### Key Concepts

- Service mesh concepts (data plane vs control plane)
- mTLS between services
- Traffic splitting and canary deployments
- Observability (golden metrics: latency, traffic, errors, saturation)

---

## Tools Quick Reference


| Tool         | Purpose                    | Install Method               |
| ------------ | -------------------------- | ---------------------------- |
| kubectl      | Cluster CLI                | Comes with k3s               |
| Helm         | Package manager            | Script install               |
| Traefik      | Ingress controller         | Built into k3s               |
| cert-manager | TLS certificates           | Helm                         |
| Prometheus   | Metrics collection         | Helm (kube-prometheus-stack) |
| Grafana      | Dashboards                 | Helm (kube-prometheus-stack) |
| Longhorn     | Distributed storage        | Helm                         |
| OpenEBS      | Storage (alternative)      | Helm                         |
| ArgoCD       | GitOps                     | Helm                         |
| MinIO        | S3-compatible object store | Helm                         |
| Velero       | Backup/restore             | Helm                         |
| Linkerd      | Service mesh               | CLI + Helm                   |


---

## Notes / To Do

- Partition USB drives (20GB k3s / 12GB longhorn)
- Install k3s on both nodes
- Set up rpi-connect auth key on mou-pi4
- Expose vcgencmd metrics to Prometheus
- Get proper 27W USB-C PSU for mou-pi5
- Add Linux desktop as 3rd node when ready
- Try Longhorn vs OpenEBS and compare

---

## Useful Commands Learned So Far

```bash
# Force reboot when system is broken
echo b > /proc/sysrq-trigger

# Safe reboot sequence (REISUB)
for c in r e i s u b; do echo $c > /proc/sysrq-trigger; sleep 1; done

# Check Pi power/throttling status
vcgencmd get_throttled   # 0x0 = all good

# All Pi metrics in one shot
for cmd in measure_temp "measure_volts core" get_throttled "measure_clock arm"; do
    echo "$cmd: $(vcgencmd $cmd)"
done

# Fix stale blkid cache
sudo blkid -c /dev/null

# Fix partition outside disk error after dd clone
sudo fdisk /dev/sdX   # delete and recreate last partition with same start sector

# Fix filesystem size after partition resize
sudo e2fsck -f /dev/sdX2
sudo resize2fs /dev/sdX2
```

## Install metrics

```shell
# Verify it's not already there
kubectl get pods -n kube-system | grep metrics

# Deploy metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch to add --kubelet-insecure-tls
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

```

## Install prometheus

```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

Validate that it worked:
```shell
kubectl --namespace monitoring get pods -l "release=kube-prometheus-stack"
```

Get Grafana 'admin' user password by running:
```shell
kubectl --namespace monitoring get secrets kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

Access Grafana local instance:
```
export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=kube-prometheus-stack" -oname)
kubectl --namespace monitoring port-forward $POD_NAME 3000
```

Get your grafana admin user password by running:
```shell
kubectl get secret --namespace monitoring -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" | base64 --decode ; echo
```

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.

### Enable ingress for prometheus/grafana

```shell
kubectl apply -f - << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
  - host: grafana.manjaro.internal
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kube-prometheus-stack-grafana
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
  - host: prometheus.manjaro.internal
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kube-prometheus-stack-prometheus
            port:
              number: 9090
EOF
```