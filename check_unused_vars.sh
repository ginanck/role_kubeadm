#!/bin/bash

# Extract all variable names from defaults/main.yml
variables=$(grep -E "^[a-zA-Z_][a-zA-Z0-9_]*:" defaults/main.yml | cut -d: -f1 | sort)

unused_vars=()
used_vars=()

echo "Checking variable usage..."
echo "=========================="

for var in $variables; do
    # Check if variable is used in any file except defaults/main.yml and README.md
    usage=$(find . -type f \( -name "*.yml" -o -name "*.j2" \) -not -path "./defaults/main.yml" -not -path "./README.md" -exec grep -l "$var" {} \; 2>/dev/null)
    
    if [ -z "$usage" ]; then
        unused_vars+=("$var")
        echo "❌ UNUSED: $var"
    else
        used_vars+=("$var")
        echo "✅ USED: $var in: $(echo $usage | tr '\n' ' ')"
    fi
done

echo ""
echo "SUMMARY"
echo "======="
echo "Total variables: $(echo "$variables" | wc -l)"
echo "Used variables: ${#used_vars[@]}"
echo "Unused variables: ${#unused_vars[@]}"

if [ ${#unused_vars[@]} -gt 0 ]; then
    echo ""
    echo "UNUSED VARIABLES:"
    echo "=================="
    for var in "${unused_vars[@]}"; do
        echo "- $var"
    done
fi
