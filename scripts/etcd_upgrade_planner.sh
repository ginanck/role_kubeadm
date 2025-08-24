#!/bin/bash

# etcd/etcdctl Upgrade Path Planner
# Usage: ./etcd_upgrade_planner.sh <current_version>
# Example: ./etcd_upgrade_planner.sh v3.5.15

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <current_version>"
    echo "Example: $0 v3.5.15"
    exit 1
fi

CURRENT_VERSION="$1"

# Clean current version (remove any prerelease suffix and ensure v prefix)
if [[ ! "$CURRENT_VERSION" =~ ^v ]]; then
    CURRENT_VERSION="v$CURRENT_VERSION"
fi
CURRENT_CLEAN=$(echo "$CURRENT_VERSION" | sed 's/-.*$//')

# Parse current version components
CURRENT_CLEAN_NO_V=$(echo "$CURRENT_CLEAN" | sed 's/^v//')
IFS='.' read -r CURRENT_MAJOR CURRENT_MINOR CURRENT_PATCH <<< "$CURRENT_CLEAN_NO_V"

echo "🔍 Analyzing upgrade path from etcd $CURRENT_VERSION"
echo "📡 Fetching available versions from GitHub..."

# Custom sort function for proper version ordering
sort_versions() {
    while IFS= read -r version; do
        # Extract base version and prerelease suffix
        base_version=$(echo "$version" | sed 's/-.*$//')
        suffix=$(echo "$version" | sed 's/^[^-]*-*//; s/^$/stable/')
        
        # Create sortable key: base_version + prerelease_priority + suffix
        case "$suffix" in
            stable) priority="9" ;;
            *alpha*) priority="1" ;;
            *beta*) priority="2" ;;
            *rc*) priority="3" ;;
            *) priority="8" ;;
        esac
        
        echo "$base_version|$priority|$suffix|$version"
    done | sort -t'|' -k1,1V -k2,2n -k3,3V | cut -d'|' -f4
}

RELEASES=$(curl -s "https://api.github.com/repos/etcd-io/etcd/releases?per_page=100" | \
    jq -r '.[].tag_name' | \
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+.*' | \
    sort_versions)

echo ""
echo "📋 Current etcd version: $CURRENT_VERSION"

# Debug: Show a sample of fetched versions
echo "🔍 Sample versions fetched (first 10):"
echo "$RELEASES" | head -10
echo ""

echo "🎯 Available upgrade targets:"
echo ""

# Find valid upgrade paths
VALID_UPGRADES=()

for version in $RELEASES; do
    # Clean version (remove prerelease)
    CLEAN_VERSION=$(echo "$version" | sed 's/-.*$//')
    CLEAN_VERSION_NO_V=$(echo "$CLEAN_VERSION" | sed 's/^v//')
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CLEAN_VERSION_NO_V"
    
    # Skip if version is older (but allow prereleases of same base version)
    if [ "$MAJOR" -lt "$CURRENT_MAJOR" ] || \
       ([ "$MAJOR" -eq "$CURRENT_MAJOR" ] && [ "$MINOR" -lt "$CURRENT_MINOR" ]) || \
       ([ "$MAJOR" -eq "$CURRENT_MAJOR" ] && [ "$MINOR" -eq "$CURRENT_MINOR" ] && [ "$PATCH" -lt "$CURRENT_PATCH" ]); then
        continue
    fi
    
    # Skip if exact same version (but allow prereleases of same version)
    if [ "$MAJOR" -eq "$CURRENT_MAJOR" ] && [ "$MINOR" -eq "$CURRENT_MINOR" ] && [ "$PATCH" -eq "$CURRENT_PATCH" ] && [ "$version" = "$CLEAN_VERSION" ]; then
        continue
    fi
    
    # Check upgrade type
    MAJOR_JUMP=$((MAJOR - CURRENT_MAJOR))
    MINOR_JUMP=$((MINOR - CURRENT_MINOR))
    
    # Same minor version (patch upgrades or same version prereleases)
    if [ "$MAJOR_JUMP" -eq 0 ] && [ "$MINOR_JUMP" -eq 0 ]; then
        if [ "$version" = "$CLEAN_VERSION" ]; then
            echo "  ✅ $version (patch upgrade - safe)"
        else
            # Check if it's a prerelease of same base version or patch prerelease
            if [ "$PATCH" -eq "$CURRENT_PATCH" ]; then
                echo "  ⚠️  $version (same version prerelease - requires etcd_release_allow_prerelease: true)"
            else
                echo "  ⚠️  $version (patch prerelease - requires etcd_release_allow_prerelease: true)"
            fi
        fi
        VALID_UPGRADES+=("$version")
    
    # Next minor version only (etcd follows strict upgrade policy)
    elif [ "$MAJOR_JUMP" -eq 0 ] && [ "$MINOR_JUMP" -eq 1 ]; then
        if [ "$version" = "$CLEAN_VERSION" ]; then
            echo "  ✅ $version (minor upgrade - next step, requires cluster downtime)"
        else
            echo "  ⚠️  $version (minor upgrade with prerelease - requires cluster downtime and etcd_release_allow_prerelease: true)"
        fi
        VALID_UPGRADES+=("$version")
    
    # Future minor versions (blocked - etcd requires sequential upgrades)
    elif [ "$MAJOR_JUMP" -eq 0 ] && [ "$MINOR_JUMP" -gt 1 ]; then
        echo "  ❌ $version (blocked - etcd requires sequential minor version upgrades)"
    
    # Major version jump (blocked - requires special migration process)
    elif [ "$MAJOR_JUMP" -gt 0 ]; then
        echo "  ❌ $version (blocked - major version upgrade requires special migration process)"
    fi
done

echo ""
echo "🗺️  UPGRADE PLAN:"

if [ ${#VALID_UPGRADES[@]} -eq 0 ]; then
    echo "  No valid upgrades found. You may already be on the latest version."
    exit 0
fi

# Show step-by-step upgrade plan for etcd
STEP=1
CURRENT_STEP="$CURRENT_VERSION"

echo "  📊 Sequential upgrade path (etcd requires one minor version at a time):"

for target in "${VALID_UPGRADES[@]}"; do
    TARGET_CLEAN=$(echo "$target" | sed 's/-.*$//')
    TARGET_CLEAN_NO_V=$(echo "$TARGET_CLEAN" | sed 's/^v//')
    IFS='.' read -r TARGET_MAJOR TARGET_MINOR TARGET_PATCH <<< "$TARGET_CLEAN_NO_V"
    
    CURRENT_STEP_CLEAN=$(echo "$CURRENT_STEP" | sed 's/-.*$//')
    CURRENT_STEP_CLEAN_NO_V=$(echo "$CURRENT_STEP_CLEAN" | sed 's/^v//')
    IFS='.' read -r STEP_MAJOR STEP_MINOR STEP_PATCH <<< "$CURRENT_STEP_CLEAN_NO_V"
    
    # If this is the next minor version
    if [ "$TARGET_MINOR" -eq $((STEP_MINOR + 1)) ]; then
        echo "    Step $STEP: $CURRENT_STEP → $target (minor upgrade - requires downtime)"
        CURRENT_STEP="$target"
        ((STEP++))
    # If this is a patch in current minor
    elif [ "$TARGET_MINOR" -eq "$STEP_MINOR" ] && [ "$STEP" -eq 1 ]; then
        echo "    Step $STEP: $CURRENT_STEP → $target (patch upgrade - rolling upgrade possible)"
        CURRENT_STEP="$target"
        ((STEP++))
    fi
done

echo ""
echo "⚠️  ETCD UPGRADE WARNINGS:"
echo "  • etcd follows a strict upgrade policy - only one minor version jump allowed"
echo "  • Minor version upgrades typically require cluster downtime"
echo "  • Always backup etcd data before upgrading (etcdctl snapshot save)"
echo "  • Test upgrades in non-production environments first"
echo "  • Ensure Kubernetes compatibility with etcd version"

echo ""
echo "🔄 KUBERNETES COMPATIBILITY:"
echo "  • Kubernetes 1.28+: etcd 3.5.x"
echo "  • Kubernetes 1.26-1.27: etcd 3.5.x"
echo "  • Kubernetes 1.24-1.25: etcd 3.5.x or 3.4.x"
echo "  • Check your Kubernetes version before upgrading etcd"

echo ""
echo "💡 RECOMMENDATIONS:"
echo "  • Always backup etcd before upgrading:"
echo "    etcdctl snapshot save backup.db"
echo "  • Verify backup integrity:"
echo "    etcdctl snapshot status backup.db"
echo "  • For production clusters, plan for downtime during minor upgrades"
echo "  • Monitor etcd health after upgrades"

echo ""
echo "🔧 ANSIBLE CONFIGURATION:"
echo "  1. Add to defaults/main.yml:"
echo "     etcd_version: <target_version>"
echo "     etcd_release_allow_prerelease: false  # Set to true for prerelease versions"
echo "  2. Ensure etcd backup before running playbook"
echo "  3. Run the playbook to install/upgrade etcd"

echo ""
echo "📖 USEFUL LINKS:"
echo "  • etcd Releases: https://github.com/etcd-io/etcd/releases"
echo "  • etcd Documentation: https://etcd.io/docs/"
echo "  • etcd Upgrade Guide: https://etcd.io/docs/latest/upgrades/"
echo "  • Kubernetes etcd Requirements: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd/"
