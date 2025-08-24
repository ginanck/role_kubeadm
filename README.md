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

### Cluster Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_config_kubernetes_version` | `1.30.13` | Kubernetes version to install |
| `kubernetes_cluster_config_cluster_name` | `kubernetes` | Name of the Kubernetes cluster |
| `kubernetes_cluster_config_networking_service_subnet` | `10.96.0.0/12` | Service subnet CIDR |
| `kubernetes_cluster_config_networking_pod_subnet` | `10.244.0.0/16` | Pod subnet CIDR |
| `kubernetes_cluster_config_networking_dns_domain` | `cluster.local` | Cluster DNS domain |

### Control Plane Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_init_config_local_advertise_address` | `172.16.3.101` | Local advertise address for the first master |
| `kubernetes_cluster_init_config_local_advertise_port` | `6443` | Local advertise port for the first master |
| `kubernetes_cluster_config_control_plane_endpoint_url` | `172.16.3.101` | Control plane endpoint URL (for external LB) |
| `kubernetes_cluster_config_control_plane_endpoint_port` | `6443` | Control plane endpoint port |
| `kubernetes_cluster_init_config_path` | `/tmp` | Path for cluster initialization config |

### API Server Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_config_api_server_extra_args` | `[Node, RBAC]` | Additional API server arguments |
| `kubernetes_cluster_config_api_server_timeout_for_controlplane_seconds` | `4m0s` | API server timeout for control plane |

### Controller Manager Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_config_controller_manager_extra_args` | See defaults | Extra arguments for controller manager |

### Scheduler Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_config_scheduler_extra_args` | See defaults | Extra arguments for scheduler |

### ETCD Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_config_etcd_local.dataDir` | `/var/lib/etcd` | ETCD data directory |

### Proxy Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_proxy_mode` | `ipvs` | Kube-proxy mode (ipvs/iptables) |
| `kubernetes_cluster_proxy_ipvs_strict_arp` | `true` | Enable strict ARP for IPVS |

### Network Plugin Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_cluster_pod_network_type` | `calico` | CNI plugin type |
| `kubernetes_calico_version` | `v3.30.0` | Calico version |
| `kubernetes_calico_deployment_type` | `medium` | Calico deployment size (medium/large) |

### Metrics Server Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_metric_server_version` | `v0.7.2` | Metrics server version |
| `kubernetes_metric_server_deployment_type` | `high-availability` | Deployment mode (high-availability/single) |

### Traffic/Ingress Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_traffic_type` | `gateway-api` | Traffic type (gateway-api/ingress-nginx) |
| `kubernetes_traffic_deployment_type` | `standard` | Deployment type (standard/minimal/complete) |
| `kubernetes_traffic_deployment_version` | `v1.3.0` | Traffic controller version |
| `kubernetes_traffic_deployment_resource` | `nginx-gateway-fabric` | Traffic resource name |
| `kubernetes_traffic_deployment_resource_version` | `v1.6.2` | Traffic resource version |

### Kubelet Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_kubelet_config_path` | `/var/lib/kubelet` | Kubelet config path |
| `kubernetes_kubelet_authentication_anonymous_enabled` | `false` | Enable anonymous authentication |
| `kubernetes_kubelet_authentication_webhook_enabled` | `true` | Enable webhook authentication |
| `kubernetes_kubelet_authorization_mode` | `Webhook` | Authorization mode |
| `kubernetes_kubelet_cgroupDriver` | `systemd` | Cgroup driver |
| `kubernetes_kubelet_clusterDNS` | `10.96.0.10` | Cluster DNS IP |
| `kubernetes_kubelet_containerRuntimeEndpoint` | `/run/containerd/containerd.sock` | Container runtime endpoint |
| `kubernetes_kubelet_failSwapOn` | `false` | Fail if swap is on |
| `kubernetes_kubelet_rotateCertificates` | `true` | Enable certificate rotation |
| `kubernetes_kubelet_serverTLSBootstrap` | `true` | Enable server TLS bootstrap |

### System Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_sysctl_conf_file` | `99-kubernetes.conf` | Sysctl configuration file name |
| `kubernetes_sysctl_parameters` | See defaults | List of sysctl parameters |

### Binary and Download Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_binary_dir` | `/opt/k8s/bin` | Kubernetes binary directory |
| `kubernetes_binary_link_path` | `/usr/bin` | Path to link binaries |
| `kubernetes_release_type` | `stable` | Release type (stable/latest) |
| `kubernetes_release_arch` | `amd64` | Architecture |
| `kubernetes_release_base_url` | `https://dl.k8s.io` | Kubernetes download base URL |

### Operation Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_kubeadm_delay` | `30` | Delay between operations (seconds) |
| `kubernetes_kubeadm_retry` | `30` | Number of retries for operations |
| `kubernetes_kubeadm_upgrade_drain_timeout` | `600s` | Timeout for node draining during upgrades |

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
172.16.3.101 base_hostname=k8s-master-01 kubernetes_cluster_init_master=true

[k8s_worker]
172.16.3.111 base_hostname=k8s-worker-01
172.16.3.112 base_hostname=k8s-worker-02
```

### 2. Run the Playbook

Execute the playbook to install and configure your Kubernetes cluster:

```bash
ansible-playbook -i inventory/hosts site.yml --ask-vault-pass
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

Use the included upgrade planner script to determine valid upgrade paths:

```bash
# Check possible upgrades from your current version
bash ./scripts/upgrade_planner.sh 1.30.11

# Example output:
# 🗺️  UPGRADE PLAN:
#   Step 1: 1.30.11 → 1.30.13 (patch upgrade)
#   Step 2: 1.30.13 → 1.31.12
#   Step 3: 1.31.12 → 1.32.8
#   Step 4: 1.32.8 → 1.33.4
```

The script shows:
- ✅ Valid upgrade targets (respects kubeadm's 1-minor-version rule)
- ❌ Blocked upgrades with clear reasons
- ⚠️ Pre-release versions requiring `kubernetes_allow_prerelease: true`
- 🗺️ Step-by-step upgrade plan

**Upgrade Rules:**
- **Minor versions**: Maximum 1 at a time (1.30→1.31, not 1.30→1.32)
- **Patch versions**: Unlimited within same minor (1.30.11→1.30.13)
- **Pre-releases**: Require `kubernetes_allow_prerelease: true`
- **Downgrades**: Not supported

### Network Configuration
- Automatically installs and configures Calico CNI
- Sets up metrics server for resource monitoring
- Configures gateway API or ingress-nginx for traffic management

## License

GPL-2.0-or-later

## Author Information

Created by Gorkem Korkmaz for automated Kubernetes cluster deployment and management.
