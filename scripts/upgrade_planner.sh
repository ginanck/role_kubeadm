#!/bin/bash

# Kubernetes Upgrade Path Planner
# Usage: ./k8s_upgrade_planner.sh <current_version>
# Example: ./k8s_upgrade_planner.sh 1.30.11

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <current_version>"
    echo "Example: $0 1.30.11"
    exit 1
fi

CURRENT_VERSION="$1"

# Clean current version (remove any prerelease suffix)
CURRENT_CLEAN=$(echo "$CURRENT_VERSION" | sed 's/-.*$//')

# Parse current version components
IFS='.' read -r CURRENT_MAJOR CURRENT_MINOR CURRENT_PATCH <<< "$CURRENT_CLEAN"

echo "🔍 Analyzing upgrade path from Kubernetes $CURRENT_VERSION"
echo "📡 Fetching available versions from GitHub..."

# Fetch all releases from GitHub
RELEASES=$(curl -s "https://api.github.com/repos/kubernetes/kubernetes/releases?per_page=100" | \
    jq -r '.[].tag_name' | \
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+' | \
    sed 's/^v//' | \
    sort -V)

echo ""
echo "📋 Current cluster: $CURRENT_VERSION"
echo "🎯 Available upgrade targets:"
echo ""

# Find valid upgrade paths
VALID_UPGRADES=()
NEXT_MINOR_FOUND=false

for version in $RELEASES; do
    # Clean version (remove prerelease)
    CLEAN_VERSION=$(echo "$version" | sed 's/-.*$//')
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CLEAN_VERSION"
    
    # Skip if version is older or same
    if [ "$MAJOR" -lt "$CURRENT_MAJOR" ] || \
       ([ "$MAJOR" -eq "$CURRENT_MAJOR" ] && [ "$MINOR" -lt "$CURRENT_MINOR" ]) || \
       ([ "$MAJOR" -eq "$CURRENT_MAJOR" ] && [ "$MINOR" -eq "$CURRENT_MINOR" ] && [ "$PATCH" -le "$CURRENT_PATCH" ]); then
        continue
    fi
    
    # Check if it's a valid upgrade target
    MAJOR_JUMP=$((MAJOR - CURRENT_MAJOR))
    MINOR_JUMP=$((MINOR - CURRENT_MINOR))
    
    # Same minor version (patch upgrades)
    if [ "$MAJOR_JUMP" -eq 0 ] && [ "$MINOR_JUMP" -eq 0 ]; then
        echo "  ✅ $version (patch upgrade - safe)"
        VALID_UPGRADES+=("$version")
    
    # Next minor version only
    elif [ "$MAJOR_JUMP" -eq 0 ] && [ "$MINOR_JUMP" -eq 1 ]; then
        if [ "$version" = "$CLEAN_VERSION" ]; then
            echo "  ✅ $version (minor upgrade - next step)"
        else
            echo "  ⚠️  $version (minor upgrade with prerelease - requires --allow-experimental-upgrades)"
        fi
        VALID_UPGRADES+=("$version")
        NEXT_MINOR_FOUND=true
    
    # Future versions (blocked)
    elif [ "$MAJOR_JUMP" -eq 0 ] && [ "$MINOR_JUMP" -gt 1 ]; then
        echo "  ❌ $version (blocked - too many minor versions ahead)"
    
    # Major version jump (blocked)
    elif [ "$MAJOR_JUMP" -gt 0 ]; then
        echo "  ❌ $version (blocked - major version upgrade not supported)"
    fi
done

echo ""
echo "🗺️  UPGRADE PLAN:"

if [ ${#VALID_UPGRADES[@]} -eq 0 ]; then
    echo "  No valid upgrades found. You may already be on the latest version."
    exit 0
fi

# Show step-by-step upgrade plan
STEP=1
CURRENT_STEP="$CURRENT_VERSION"

for target in "${VALID_UPGRADES[@]}"; do
    TARGET_CLEAN=$(echo "$target" | sed 's/-.*$//')
    IFS='.' read -r TARGET_MAJOR TARGET_MINOR TARGET_PATCH <<< "$TARGET_CLEAN"
    
    CURRENT_STEP_CLEAN=$(echo "$CURRENT_STEP" | sed 's/-.*$//')
    IFS='.' read -r STEP_MAJOR STEP_MINOR STEP_PATCH <<< "$CURRENT_STEP_CLEAN"
    
    # If this is the next minor version
    if [ "$TARGET_MINOR" -eq $((STEP_MINOR + 1)) ]; then
        echo "  Step $STEP: $CURRENT_STEP → $target"
        CURRENT_STEP="$target"
        ((STEP++))
    # If this is a patch in current minor
    elif [ "$TARGET_MINOR" -eq "$STEP_MINOR" ] && [ "$STEP" -eq 1 ]; then
        echo "  Step $STEP: $CURRENT_STEP → $target (patch upgrade)"
        CURRENT_STEP="$target"
        ((STEP++))
    fi
done

echo ""
echo "💡 RECOMMENDATIONS:"
echo "  • Always backup your cluster before upgrading"
echo "  • Test upgrades in non-production environments first"
echo "  • Upgrade one minor version at a time"
echo "  • For prerelease versions, set kubernetes_allow_prerelease: true"

echo ""
echo "🔧 ANSIBLE COMMANDS:"
echo "  1. Set target version in defaults/main.yml:"
echo "     kubernetes_cluster_config_kubernetes_version: <target_version>"
echo "  2. Run the playbook to upgrade"
