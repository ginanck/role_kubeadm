#!/bin/bash

# Helm Upgrade Path Planner
# Usage: ./helm_upgrade_planner.sh <current_version>
# Example: ./helm_upgrade_planner.sh v3.12.0

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <current_version>"
    echo "Example: $0 v3.12.0"
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

echo "🔍 Analyzing upgrade path from Helm $CURRENT_VERSION"
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

RELEASES=$(curl -s "https://api.github.com/repos/helm/helm/releases?per_page=100" | \
    jq -r '.[].tag_name' | \
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+.*' | \
    sort_versions)

echo ""
echo "📋 Current Helm version: $CURRENT_VERSION"

# Debug: Show a sample of fetched versions
echo "🔍 Sample versions fetched (first 10):"
echo "$RELEASES" | head -10
echo ""

echo "🎯 Available upgrade targets:"
echo ""

# Find valid upgrade paths
VALID_UPGRADES=()
NEXT_MINOR_FOUND=false

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
                echo "  ⚠️  $version (same version prerelease - requires helm_release_allow_prerelease: true)"
            else
                echo "  ⚠️  $version (patch prerelease - requires helm_release_allow_prerelease: true)"
            fi
        fi
        VALID_UPGRADES+=("$version")
    
    # Minor version upgrades (Helm allows any minor version jump)
    elif [ "$MAJOR_JUMP" -eq 0 ] && [ "$MINOR_JUMP" -gt 0 ]; then
        if [ "$version" = "$CLEAN_VERSION" ]; then
            echo "  ✅ $version (minor upgrade - safe)"
        else
            echo "  ⚠️  $version (minor upgrade with prerelease - requires helm_release_allow_prerelease: true)"
        fi
        VALID_UPGRADES+=("$version")
    
    # Major version jump (generally safe for Helm v3.x)
    elif [ "$MAJOR_JUMP" -gt 0 ]; then
        if [ "$version" = "$CLEAN_VERSION" ]; then
            echo "  ⚠️  $version (major version upgrade - review breaking changes)"
        else
            echo "  ⚠️  $version (major version upgrade with prerelease - review breaking changes, requires helm_release_allow_prerelease: true)"
        fi
        VALID_UPGRADES+=("$version")
    fi
done

echo ""
echo "🗺️  UPGRADE PLAN:"

if [ ${#VALID_UPGRADES[@]} -eq 0 ]; then
    echo "  No valid upgrades found. You may already be on the latest version."
    exit 0
fi

# Show recommended upgrade targets
echo "  📊 Recommended upgrade targets:"
PATCH_UPGRADES=()
MINOR_UPGRADES=()
MAJOR_UPGRADES=()

for version in "${VALID_UPGRADES[@]}"; do
    CLEAN_VERSION=$(echo "$version" | sed 's/-.*$//')
    CLEAN_VERSION_NO_V=$(echo "$CLEAN_VERSION" | sed 's/^v//')
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CLEAN_VERSION_NO_V"
    
    MAJOR_JUMP=$((MAJOR - CURRENT_MAJOR))
    MINOR_JUMP=$((MINOR - CURRENT_MINOR))
    
    if [ "$MAJOR_JUMP" -eq 0 ] && [ "$MINOR_JUMP" -eq 0 ]; then
        PATCH_UPGRADES+=("$version")
    elif [ "$MAJOR_JUMP" -eq 0 ] && [ "$MINOR_JUMP" -gt 0 ]; then
        MINOR_UPGRADES+=("$version")
    elif [ "$MAJOR_JUMP" -gt 0 ]; then
        MAJOR_UPGRADES+=("$version")
    fi
done

# Show latest patch upgrade
if [ ${#PATCH_UPGRADES[@]} -gt 0 ]; then
    LATEST_PATCH="${PATCH_UPGRADES[-1]}"
    echo "    Latest patch: $CURRENT_VERSION → $LATEST_PATCH (recommended)"
fi

# Show latest minor upgrade
if [ ${#MINOR_UPGRADES[@]} -gt 0 ]; then
    LATEST_MINOR="${MINOR_UPGRADES[-1]}"
    echo "    Latest minor: $CURRENT_VERSION → $LATEST_MINOR"
fi

# Show latest major upgrade
if [ ${#MAJOR_UPGRADES[@]} -gt 0 ]; then
    LATEST_MAJOR="${MAJOR_UPGRADES[-1]}"
    echo "    Latest major: $CURRENT_VERSION → $LATEST_MAJOR (review breaking changes)"
fi

echo ""
echo "💡 RECOMMENDATIONS:"
echo "  • Always backup your Helm releases before upgrading"
echo "  • Test upgrades in non-production environments first"
echo "  • Review release notes for breaking changes, especially for major upgrades"
echo "  • For prerelease versions, set helm_release_allow_prerelease: true"
echo "  • Helm 3.x is generally backward compatible within major versions"

echo ""
echo "🔧 ANSIBLE CONFIGURATION:"
echo "  1. Add to defaults/main.yml:"
echo "     helm_version: <target_version>"
echo "     helm_release_allow_prerelease: false  # Set to true for prerelease versions"
echo "  2. Run the playbook to install/upgrade Helm"

echo ""
echo "📖 USEFUL LINKS:"
echo "  • Helm Releases: https://github.com/helm/helm/releases"
echo "  • Helm Documentation: https://helm.sh/docs/"
echo "  • Helm Version Support Policy: https://helm.sh/docs/topics/version_skew/"
