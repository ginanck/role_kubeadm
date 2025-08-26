# role_kubeadm

An Ansible role for installing and managing Kubernetes clusters using kubeadm. This role automatically initializes the first master node, joins additional master nodes from the inventory, joins worker nodes to the cluster, and performs automatic upgrades when version changes are detected.

## Features

- Automatic first master node initialization
- Seamless joining of additional master nodes for HA setup
- Worker node joining with automatic configuration
- Version change detection and automatic cluster upgrades
- Configurable network policies and CNI plugins
- Support for external load balancers for multi-master setups
- Comprehensive kubelet and cluster configuration

## Requirements

- Ansible 2.1 or higher
- Ubuntu/Debian or RedHat/CentOS target systems
- Container runtime (containerd) already installed (use role_containerd)
- Proper network connectivity between nodes
- Root or sudo access on target hosts

## Role Variables

### K8S Configuration

#### OS-Specific Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_prerequisite_packages` | See OS-specific files | Prerequisite packages (defined in `vars/Debian.yml` and `vars/RedHat.yml`) |

**Debian/Ubuntu packages**:
  - `apt-transport-https`
  - `ca-certificates`
  - `curl`
  - `gnupg`
  - `lsb-release`
  - `libc6`
  - `conntrack`

**RedHat/CentOS packages**:
  - `dnf-plugins-core`
  - `yum-utils`
  - `glibc`
  - `conntrack`

#### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_dir` | `/etc/kubernetes` | Main Kubernetes configuration directory |
| `kubernetes_kubeconfig_path` | `{{ kubernetes_dir }}/admin.conf` | Path to kubeconfig file |
| `kubernetes_kubeadm_delay` | `30` | Delay between operations (seconds) |
| `kubernetes_kubeadm_retry` | `30` | Number of retries for operations |
| `kubernetes_kubeadm_upgrade_drain_timeout` | `600s` | Timeout for node draining during upgrades |

#### Cluster Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_config_kubernetes_version` | `1.30.11` | Kubernetes version to install |
| `kubernetes_cluster_config_cluster_name` | `kubernetes` | Name of the Kubernetes cluster |
| `kubernetes_cluster_config_networking_service_subnet` | `10.96.0.0/12` | Service subnet CIDR |
| `kubernetes_cluster_config_networking_pod_subnet` | `10.244.0.0/16` | Pod subnet CIDR |
| `kubernetes_cluster_config_networking_dns_domain` | `cluster.local` | Cluster DNS domain |

#### Control Plane Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_init_config_local_advertise_address` | `172.16.3.101` | Local advertise address for the first master |
| `kubernetes_cluster_init_config_local_advertise_port` | `6443` | Local advertise port for the first master |
| `kubernetes_cluster_config_control_plane_endpoint_url` | `172.16.3.101` | Control plane endpoint URL (for external LB) |
| `kubernetes_cluster_config_control_plane_endpoint_port` | `6443` | Control plane endpoint port |
| `kubernetes_cluster_init_config_path` | `/tmp` | Path for cluster initialization config |

#### API Server Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_config_api_server_extra_args` | `[Node, RBAC]` | Additional API server arguments |
| `kubernetes_cluster_config_api_server_timeout_for_controlplane_seconds` | `4m0s` | API server timeout for control plane |
| `kubernetes_cluster_config_additional_sans` | `[]` | Additional Subject Alternative Names for API server certificate |

#### Controller Manager Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_config_controller_manager_extra_args` | See defaults | Extra arguments for controller manager |
| `kubernetes_cluster_config_controller_manager_extra_args.bind-address` | `0.0.0.0` | Controller manager bind address |
| `kubernetes_cluster_config_controller_manager_extra_args.node-monitor-period` | `5s` | Node monitor period |
| `kubernetes_cluster_config_controller_manager_extra_args.node-monitor-grace-period` | `15s` | Node monitor grace period |
| `kubernetes_cluster_config_controller_manager_extra_args.secure-port` | `10257` | Controller manager secure port |

#### Scheduler Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_config_scheduler_extra_args` | See defaults | Extra arguments for scheduler |
| `kubernetes_cluster_config_scheduler_extra_args.bind-address` | `0.0.0.0` | Scheduler bind address |
| `kubernetes_cluster_config_scheduler_extra_args.secure-port` | `10259` | Scheduler secure port |

#### ETCD Cluster Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_config_etcd_local.dataDir` | `/var/lib/etcd` | ETCD data directory |

#### Proxy Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_proxy_mode` | `ipvs` | Kube-proxy mode (ipvs/iptables) |
| `kubernetes_cluster_proxy_ipvs_strict_arp` | `true` | Enable strict ARP for IPVS |

#### Network Plugin Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_pod_network_type` | `calico` | CNI plugin type |
| `kubernetes_calico_version` | `v3.30.0` | Calico version |
| `kubernetes_calico_deployment_type` | `small` | Calico deployment size (`small` for ≤50 nodes, `large` for >50 nodes) |
| `kubernetes_calico_base_url` | `https://raw.githubusercontent.com/projectcalico/calico` | Base URL for Calico manifests |
| `kubernetes_calico_manifests` | `{small: calico.yaml, large: calico-typha.yaml}` | Calico manifest files by deployment type |

**Calico Deployment Types:**
- `small`: Uses standard Calico manifest (`calico.yaml`) - suitable for clusters with 50 nodes or fewer
- `large`: Uses Calico with Typha (`calico-typha.yaml`) - recommended for clusters with more than 50 nodes for better performance

#### Kubelet Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_kubelet_config_path` | `/var/lib/kubelet` | Kubelet config path |
| `kubernetes_kubelet_authentication_anonymous_enabled` | `false` | Enable anonymous authentication |
| `kubernetes_kubelet_authentication_webhook_cacheTTL` | `0s` | Webhook authentication cache TTL |
| `kubernetes_kubelet_authentication_webhook_enabled` | `true` | Enable webhook authentication |
| `kubernetes_kubelet_authentication_x509_clientCAFile` | `/etc/kubernetes/pki/ca.crt` | Client CA file for x509 authentication |
| `kubernetes_kubelet_authorization_mode` | `Webhook` | Authorization mode |
| `kubernetes_kubelet_authorization_webhook_cacheAuthorizedTTL` | `0s` | Webhook authorization cache TTL for authorized requests |
| `kubernetes_kubelet_authorization_webhook_cacheUnauthorizedTTL` | `0s` | Webhook authorization cache TTL for unauthorized requests |
| `kubernetes_kubelet_cgroupDriver` | `systemd` | Cgroup driver |
| `kubernetes_kubelet_clusterDNS` | `10.96.0.10` | Cluster DNS IP |
| `kubernetes_kubelet_clusterDomain` | `{{ kubernetes_cluster_config_networking_dns_domain }}` | Cluster domain |
| `kubernetes_kubelet_containerRuntimeEndpoint` | `/run/containerd/containerd.sock` | Container runtime endpoint |
| `kubernetes_kubelet_cpuManagerReconcilePeriod` | `0s` | CPU manager reconcile period |
| `kubernetes_kubelet_evictionPressureTransitionPeriod` | `0s` | Eviction pressure transition period |
| `kubernetes_kubelet_failSwapOn` | `false` | Fail if swap is on |
| `kubernetes_kubelet_fileCheckFrequency` | `0s` | File check frequency |
| `kubernetes_kubelet_healthzBindAddress` | `127.0.0.1` | Healthz bind address |
| `kubernetes_kubelet_healthzPort` | `10248` | Healthz port |
| `kubernetes_kubelet_httpCheckFrequency` | `0s` | HTTP check frequency |
| `kubernetes_kubelet_imageMaximumGCAge` | `0s` | Image maximum garbage collection age |
| `kubernetes_kubelet_imageMinimumGCAge` | `0s` | Image minimum garbage collection age |
| `kubernetes_kubelet_logging_flushFrequency` | `0` | Logging flush frequency |
| `kubernetes_kubelet_logging_options_json_infoBufferSize` | `0` | JSON logging info buffer size |
| `kubernetes_kubelet_logging_options_text_infoBufferSize` | `0` | Text logging info buffer size |
| `kubernetes_kubelet_logging_verbosity` | `0` | Logging verbosity |
| `kubernetes_kubelet_nodeStatusReportFrequency` | `0s` | Node status report frequency |
| `kubernetes_kubelet_nodeStatusUpdateFrequency` | `0s` | Node status update frequency |
| `kubernetes_kubelet_rotateCertificates` | `true` | Enable certificate rotation |
| `kubernetes_kubelet_runtimeRequestTimeout` | `0s` | Runtime request timeout |
| `kubernetes_kubelet_serverTLSBootstrap` | `true` | Enable server TLS bootstrap |
| `kubernetes_kubelet_shutdownGracePeriod` | `0s` | Shutdown grace period |
| `kubernetes_kubelet_shutdownGracePeriodCriticalPods` | `0s` | Shutdown grace period for critical pods |
| `kubernetes_kubelet_staticPodPath` | `/etc/kubernetes/manifests` | Static pod path |
| `kubernetes_kubelet_streamingConnectionIdleTimeout` | `0s` | Streaming connection idle timeout |
| `kubernetes_kubelet_syncFrequency` | `0s` | Sync frequency |
| `kubernetes_kubelet_volumeStatsAggPeriod` | `0s` | Volume stats aggregation period |

#### System Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_sysctl_conf_file` | `99-kubernetes.conf` | Sysctl configuration file name |
| `kubernetes_sysctl_parameters` | See defaults | List of sysctl parameters |
| `kubernetes_systemd_path` | `/etc/systemd/system` | Systemd service path |

#### Binary and Download Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_binary_dir` | `/opt/k8s/bin` | Kubernetes binary directory |
| `kubernetes_binary_link_path` | `/usr/bin` | Path to link binaries |
| `kubernetes_release_allow_prerelease` | `false` | Enable alpha/beta/rc version upgrades |
| `kubernetes_release_version` | `v{{ kubernetes_cluster_config_kubernetes_version }}` | Kubernetes version to download |
| `kubernetes_release_arch` | `amd64` | Architecture for binaries |
| `kubernetes_release_base_url` | `https://dl.k8s.io/release` | Kubernetes download base URL |
| `kubernetes_release_download_url` | Computed URL | Full download URL for binaries |
| `kubernetes_release_upstream_url` | GitHub API URL | GitHub API URL for Kubernetes releases |

#### Node Retirement Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_retired_nodes` | `[]` | List of retired nodes (hostname and IP) |

### ETCD Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `etcd_install_enabled` | `true` | Enable/disable etcd/etcdctl installation |
| `etcd_version` | `v3.5.22` | etcd version to install |
| `etcd_release_arch` | `amd64` | Architecture for etcd binary |
| `etcd_release_os` | `linux` | Operating system for etcd binary |
| `etcd_release_version` | `{{ etcd_version }}` | Computed etcd version |
| `etcd_release_upstream_url` | GitHub API URL | GitHub API URL for etcd releases |

### Helm Configuration

#### Helm Binary Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `helm_install_enabled` | `true` | Enable/disable Helm installation |
| `helm_version` | `v3.16.0` | Helm version to install |
| `helm_release_arch` | `amd64` | Architecture for Helm binary |
| `helm_release_os` | `linux` | Operating system for Helm binary |
| `helm_release_version` | `{{ helm_version }}` | Computed Helm version |
| `helm_release_upstream_url` | GitHub API URL | GitHub API URL for Helm releases |
| `helm_charts_wait_timeout` | `300s` | Timeout for Helm chart operations |
| `helm_charts_additional_repositories` | `[]` | Additional Helm repositories |

#### Helm Charts Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `helm_charts` | See defaults | List of Helm charts to install |

##### Default Helm Charts

1. **Kubelet CSR Approver**
   - `chart_name`: kubelet-csr-approver
   - `chart_version`: 1.2.10
   - `release_namespace`: kube-system

2. **Metrics Server**
   - `chart_name`: metrics-server
   - `chart_version`: 3.13.0
   - `release_namespace`: kube-system

3. **NGINX Ingress Controller**
   - `chart_name`: ingress-nginx
   - `chart_version`: 4.13.1
   - `release_namespace`: ingress-nginx

## Available Tags

The role supports granular execution through tags:

| Tag | Description |
|-----|-------------|
| `k8s` | Run all Kubernetes-related tasks |
| `k8s-common` | Run common prerequisites and setup tasks |
| `k8s-binary` | Setup Kubernetes binaries (kubeadm, kubelet, kubectl) |
| `k8s-init` | Initialize the Kubernetes cluster (first master only) |
| `k8s-join` | Join nodes to the cluster |
| `k8s-upgrade` | Perform cluster upgrades |
| `k8s-remove` | Remove nodes from the cluster |
| `helm` | Setup Helm and install charts |

### Tag Usage Examples

```bash
# Install only binaries
ansible-playbook -i inventories/kubernetes setup-kubernetes.yml --tags k8s-binary

# Initialize cluster only
ansible-playbook -i inventories/kubernetes setup-kubernetes.yml --tags k8s-init

# Join nodes only
ansible-playbook -i inventories/kubernetes setup-kubernetes.yml --tags k8s-join

# Upgrade cluster only
ansible-playbook -i inventories/kubernetes setup-kubernetes.yml --tags k8s-upgrade

# Skip Helm installation
ansible-playbook -i inventories/kubernetes setup-kubernetes.yml --tags kubeadm --skip-tags helm
```

## Dependencies

This role works in conjunction with:
- `role_base` - Base system configuration
- `role_containerd` - Container runtime setup

## Example Playbook

```yaml
---
- name: Install and configure kubernetes
  hosts: kubernetes
  serial: 1
  become: true
  become_method: sudo
  gather_facts: true
  vars_files:
    - vault/github.yml

  roles:
    - role: role_base
      tags: base
    - role: role_containerd
      tags: containerd
    - role: role_kubeadm
      tags: kubeadm
```

## Configuration

### Ansible Configuration

Create an `ansible.cfg` file in your project root:

```ini
[defaults]
remote_user             = ansible
host_key_checking       = False
gathering               = smart
gather_facts            = false
forks                   = 5
collections_paths       = ./collections
roles_path              = ./roles
vault_password_file     = vault/vault_pass.txt
```

### GitHub Vault Configuration

This role may require GitHub access for downloading components. Create an encrypted vault file at `vault/github.yml`:

```yaml
# vault/github.yml (encrypted with ansible-vault)
github_access_token: <GITHUB-TOKEN>
```

To create and manage the vault file:

```bash
# Create vault password file
echo "your-vault-password" > vault/vault_pass.txt
chmod 600 vault/vault_pass.txt

# Create encrypted vault file
ansible-vault create vault/github.yml

# Or encrypt existing file
ansible-vault encrypt vault/github.yml

# View vault contents
ansible-vault view vault/github.yml

# Edit vault contents
ansible-vault edit vault/github.yml
```

## Usage

### 1. Prepare Inventory

Define your Kubernetes nodes in your Ansible inventory:

```ini
[kubernetes:children]
k8s_master
k8s_worker

[k8s_master]
172.16.3.102 base_hostname=k8s-master-02 kubernetes_cluster_init_master=true

[k8s_worker]
172.16.3.112 base_hostname=k8s-worker-02
172.16.3.113 base_hostname=k8s-worker-03
```

### 2. Run the Playbook

#### Install/Maintain Kubernetes Cluster

To install or upgrade or maintaince your Kubernetes cluster:

```bash
ansible-playbook -i inventories/kubernetes setup-kubernetes.yml --tags kubeadm --flush-cache
```

#### Remove Nodes from Cluster

To remove nodes from the cluster:

```bash
ansible-playbook -i inventories/kubernetes setup-kubernetes.yml --tags k8s,k8s-remove --skip-tags k8s-binary,k8s-init,k8s-join,k8s-upgrade,helm --flush-cache
```

#### Plan Upgrades

Before upgrading, use the planning scripts to determine valid upgrade paths:

```bash
# Plan Kubernetes upgrades
bash scripts/upgrade_planner.sh 1.30.11

# Plan etcd upgrades
bash scripts/etcd_upgrade_planner.sh v3.5.22

# Plan Helm upgrades  
bash scripts/helm_upgrade_planner.sh v3.16.0
```

#### Full Installation with All Dependencies

For a complete installation including base system and container runtime:

```bash
ansible-playbook -i inventories/kubernetes setup-kubernetes.yml --ask-vault-pass
```

### 3. Verify Installation

After installation, verify the cluster status:

```bash
kubectl get nodes
kubectl get pods -A
```

## Cluster Operations

### Automatic Cluster Initialization
- The role automatically detects the first master node and initializes the cluster
- Subsequent master nodes are automatically joined to create HA setup
- Worker nodes are automatically joined after masters are ready

### Automatic Upgrades
- The role detects version changes in configuration
- Performs rolling upgrades with proper node draining
- Maintains cluster availability during upgrades
- Validates upgrade paths to prevent invalid version jumps

### Upgrade Path Planning

Use the included upgrade planner scripts to determine valid upgrade paths:

#### Kubernetes Upgrade Planner

```bash
# Check possible upgrades from your current version
bash scripts/upgrade_planner.sh 1.30.11

# Example output:
# 🗺️  UPGRADE PLAN:
#   Step 1: 1.30.11 → 1.30.13 (patch upgrade)
#   Step 2: 1.30.13 → 1.31.12
#   Step 3: 1.31.12 → 1.32.8
#   Step 4: 1.32.8 → 1.33.4
```

#### ETCD Upgrade Planner

```bash
# Check possible etcd upgrades from your current version
bash scripts/etcd_upgrade_planner.sh v3.5.22

# Example output:
# 🗺️  UPGRADE PLAN:
#   Step 1: v3.5.22 → v3.5.25 (patch upgrade)
#   Step 2: v3.5.25 → v3.6.0
```

#### Helm Upgrade Planner

```bash
# Check possible Helm upgrades from your current version
bash scripts/helm_upgrade_planner.sh v3.16.0

# Example output:
# 🗺️  UPGRADE PLAN:
#   Step 1: v3.16.0 → v3.16.4 (patch upgrade)
#   Step 2: v3.16.4 → v3.17.0
```

The scripts show:
- ✅ Valid upgrade targets (respects version compatibility rules)
- ❌ Blocked upgrades with clear reasons
- ⚠️ Pre-release versions requiring appropriate `*_release_allow_prerelease: true` settings
- 🗺️ Step-by-step upgrade plan

**Upgrade Rules:**
- **Minor versions**: Maximum 1 at a time (1.30→1.31, not 1.30→1.32)
- **Patch versions**: Unlimited within same minor (1.30.11→1.30.13)
- **Pre-releases**: Require `kubernetes_release_allow_prerelease: true`
- **Downgrades**: Not supported

### Step-by-step upgrade plan

**Upgrade Rules:**
- **Minor versions**: Maximum 1 at a time (1.30→1.31, not 1.30→1.32)
- **Patch versions**: Unlimited within same minor (1.30.11→1.30.13)
- **Pre-releases**: Require `kubernetes_release_allow_prerelease: true`
- **Downgrades**: Not supported

### Network Configuration
- Automatically installs and configures Calico CNI
- Sets up metrics server for resource monitoring
- Configures gateway API or ingress-nginx for traffic management

### Node Retirement
- Use `kubernetes_retired_nodes` variable to exclude nodes from operations
- Useful for decommissioning nodes without removing them from inventory

## Troubleshooting

### Common Issues

**1. Node Not Joining**
```bash
# Check kubelet status
systemctl status kubelet

# Check kubelet logs
journalctl -xeu kubelet

# Verify token validity (on master)
kubeadm token list
```

**2. Certificate Issues**
```bash
# Check certificate expiration
kubeadm certs check-expiration

# Renew certificates
kubeadm certs renew all
```

**3. Network Issues**
```bash
# Check CNI plugin status
kubectl get pods -n kube-system | grep calico

# Verify network connectivity
kubectl exec -it <pod-name> -- ping <other-pod-ip>
```

### Log Locations

| Component | Log Location |
|-----------|--------------|
| kubelet | `journalctl -u kubelet` |
| containerd | `journalctl -u containerd` |
| kubeadm init | `/tmp/kubeadm-init.log` |
| API server | `/var/log/pods/kube-system_kube-apiserver-*` |

### Useful Debug Commands

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# Component status
kubectl get componentstatuses

# Events
kubectl get events --all-namespaces --sort-by='.metadata.creationTimestamp'

# Resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

## License

GPL-2.0-or-later

## Author Information

Created by Gorkem Korkmaz for automated Kubernetes cluster deployment and management.
