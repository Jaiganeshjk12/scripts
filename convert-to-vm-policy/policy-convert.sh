#!/bin/bash

# Configuration
DRY_RUN=${DRY_RUN:-false}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      echo "K10 Policy Migration Script"
      echo "Usage: $0 [--dry-run] [--help]"
      echo ""
      echo "Options:"
      echo "  --dry-run    Preview changes without applying them"
      echo "  --help       Show this help message"
      echo ""
      echo "Environment variables:"
      echo "  DRY_RUN=true   Alternative way to enable dry run mode"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Function to patch a single policy from namespace scope to VM scope
patch_policy_to_vm_scope() {
  local policy="$1"
  echo "Patching policy: $policy"
  
  # Get the current value
  local current_value=$(kubectl get policies.config.kio.kasten.io "$policy" -n kasten-io -o jsonpath='{.spec.selector.matchExpressions[0].values[0]}')
  
  # Skip kasten-io-cluster scoped policies
  if [[ "$current_value" == "kasten-io-cluster" ]]; then
    echo "  ⏭️  Skipping $policy (Cluster scoped policy should not be converted to VM scope)"
    return 0
  fi
  
  # Skip kasten-io scoped policies (e.g., k10-disaster-recovery-policy)
  if [[ "$current_value" == "kasten-io" ]]; then
    echo "  ⏭️  Skipping $policy (DR Policy should not be converted to VM scope)"
    return 0
  fi
  
  echo "  📝 Would change value: $current_value → $current_value/*"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  🔍 [DRY RUN] Would apply patch:"
    echo "    - Change selector key: k10.kasten.io/appNamespace → k10.kasten.io/virtualMachineRef"
    echo "    - Change selector value: $current_value → $current_value/*"
    echo "    - Remove exportParameters section"
    echo "  💡 [DRY RUN] No actual changes made"
  else
    echo "  🔧 Applying patch..."
    # Apply patch with the modified value
    kubectl patch policies.config.kio.kasten.io "$policy" -n kasten-io --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/selector/matchExpressions/0/key",
        "value": "k10.kasten.io/virtualMachineRef"
      },
      {
        "op": "replace",
        "path": "/spec/selector/matchExpressions/0/values/0",
        "value": "'"$current_value"'/*"
      },
      {
        "op": "remove",
        "path": "/spec/actions/1/exportParameters"
      }
    ]'
    
    echo "  ✅ Successfully patched $policy"
  fi
}

# Validation function
validate_policies() {
  echo ""
  echo "=== Policy Validation Report ==="
  echo ""
  
  for policy in $(kubectl get policies.config.kio.kasten.io -n kasten-io -o jsonpath='{.items[*].metadata.name}'); do
    selector_key=$(kubectl get policies.config.kio.kasten.io "$policy" -n kasten-io -o jsonpath='{.spec.selector.matchExpressions[0].key}' 2>/dev/null)
    
    if [[ "$selector_key" == "k10.kasten.io/virtualMachineRef" ]]; then
      echo "✓ $policy: VM scoped policy"
    elif [[ "$selector_key" == "k10.kasten.io/appNamespace" ]]; then
      echo "• $policy: Namespace scoped policy"
    else
      echo "? $policy: Unknown scope (key: $selector_key)"
    fi
  done
  
  echo ""
  echo "=== End Validation Report ==="
}

# Main execution: Find and patch namespace-scoped policies
if [[ "$DRY_RUN" == "true" ]]; then
  echo "🔍 === DRY RUN MODE: Preview Policy Migration ==="
  echo "ℹ️  No actual changes will be made"
else
  echo "🚀 === Starting Policy Migration ==="
fi
echo ""

for policy in $(kubectl get policies.config.kio.kasten.io -n kasten-io -o jsonpath='{range .items[?(@.spec.selector.matchExpressions[0].key=="k10.kasten.io/appNamespace")]}{.metadata.name}{"\n"}{end}'); do
  patch_policy_to_vm_scope "$policy"
done

echo ""
if [[ "$DRY_RUN" == "true" ]]; then
  echo "🔍 === DRY RUN Complete: No Changes Made ==="
  echo "💡 Run without --dry-run to apply changes"
else
  echo "✅ === Policy Conversion Complete ==="
fi

echo "=== Starting Validation ==="

# Run validation
validate_policies
