# K10 Policy Migration Script

A bash script to migrate Kasten K10 backup policies from **namespace-scoped** to **VM-scoped** targeting.

## Overview

This script automates the conversion of K10 backup policies that use `k10.kasten.io/appNamespace` selectors to `k10.kasten.io/virtualMachineRef` selectors, enabling VM-level backup targeting instead of namespace-level targeting.

### Important Assumptions

⚠️ **This script converts ALL namespace-scoped policies to VM-scoped policies** in the `kasten-io` namespace (excluding system policies).

If there are some namespaces that doesn't have VMs but has container workloads in it, Exclude those namespaces so that those are not converted with the env variable EXCLUDE_POLICIES.

When modifying the script:
1. **Test with dry run** on non-production clusters first
2. **Validate edge cases** (system policies, malformed policies)

### What it does

- **Discovers** policies with namespace-scoped selectors (`k10.kasten.io/appNamespace`)
- **Converts** selector key to VM-scoped (`k10.kasten.io/virtualMachineRef`) 
- **Updates** selector values from `namespace` to `namespace/*` pattern
- **Removes** migration tokens and receive strings from export parameters that are no longer usable
- **Preserves** system policies (cluster-scoped and DR policies)
- **Validates** final state of all policies

### Migration Example

**Before:**
```yaml
spec:
  selector:
    matchExpressions:
    - key: k10.kasten.io/appNamespace
      operator: In
      values:
      - mysql
  actions:
  - action: backup
  - action: export
    exportParameters:
      migrationToken: {...}
```

**After:**
```yaml
spec:
  selector:
    matchExpressions:
    - key: k10.kasten.io/virtualMachineRef
      operator: In  
      values:
      - mysql/*
  actions:
  - action: backup
  - action: export
```

## Prerequisites

- `kubectl` configured with access to the target cluster
- Permissions to read and modify `policies.config.kio.kasten.io` resources in `kasten-io` namespace
- Bash shell environment

## Installation

1. Download the script:
   ```bash
   curl -O https://raw.githubusercontent.com/Jaiganeshjk12/scripts/refs/heads/main/convert-to-vm-policy/policy-convert.sh
   chmod +x policy_convert.sh
   ```

2. Or copy the script content to a local file and make it executable.

## Usage

### Dry Run (Recommended First)

Preview what changes will be made without applying them:

```bash
./policy_convert.sh --dry-run
```

### Execute Migration

Apply the actual changes:

```bash
./policy_convert.sh
```

### Help

Display usage information:

```bash
./policy_convert.sh --help
```

The help output will show:
- Available command line options
- Environment variable documentation
- Usage examples including exclusions

### Environment Variables

**Dry Run Mode:**
```bash
DRY_RUN=true ./policy_convert.sh
```

**Exclude Specific Policies:**
```bash
EXCLUDE_POLICIES="policy1,policy2,policy3" ./policy_convert.sh --dry-run
```

**Combined Usage:**
```bash
DRY_RUN=true EXCLUDE_POLICIES="mysql-backup,test-policy" ./policy_convert.sh
```

## Examples

### Example 1: Preview Mode

```bash
$ ./policy_convert.sh --dry-run

🔍 === DRY RUN MODE: Preview Policy Migration ===
ℹ️  No actual changes will be made

Patching policy: mysql-backup
  📝 Would change value: mysql → mysql/*
  🔍 [DRY RUN] Would apply patch:
    - Change selector key: k10.kasten.io/appNamespace → k10.kasten.io/virtualMachineRef
    - Change selector value: mysql → mysql/*
    - Remove migrationToken and receiveString from exportParameters
  💡 [DRY RUN] No actual changes made

Patching policy: k10-disaster-recovery-policy
  ⏭️  Skipping k10-disaster-recovery-policy (DR Policy should not be converted to VM scope)

=== Policy Validation Report ===
✓ existing-vm-policy: VM scoped policy
• mysql-backup: Namespace scoped policy
• k10-disaster-recovery-policy: Namespace scoped policy
```

### Example 2: Actual Migration

```bash
$ ./policy_convert.sh

🚀 === Starting Policy Migration ===

Patching policy: mysql-backup
  📝 Would change value: mysql → mysql/*
  🔧 Applying patch...
  ✅ Successfully patched mysql-backup

✅ === Policy Conversion Complete ===

=== Policy Validation Report ===
✓ mysql-backup: VM scoped policy
✓ existing-vm-policy: VM scoped policy
• k10-disaster-recovery-policy: Namespace scoped policy
```

### Example 3: Using Exclusions

```bash
$ EXCLUDE_POLICIES="mysql-backup,critical-app" ./policy_convert.sh --dry-run

🔍 === DRY RUN MODE: Preview Policy Migration ===
ℹ️  No actual changes will be made
📋 Exclusion list: [mysql-backup,critical-app]

Patching policy: mysql-backup
  ⏭️  Skipping mysql-backup (excluded via EXCLUDE_POLICIES)
Patching policy: postgres-backup
  📝 Would change value: postgres → postgres/*
  🔍 [DRY RUN] Would apply patch:
    - Change selector key: k10.kasten.io/appNamespace → k10.kasten.io/virtualMachineRef
    - Change selector value: postgres → postgres/*
    - Remove migrationToken and receiveString from exportParameters
  💡 [DRY RUN] No actual changes made
```

## Safety Features

### Automatic Exclusions

The script automatically skips these policies to prevent system disruption:

- **Cluster-scoped policies**: Policies targeting `kasten-io-cluster`
- **DR policies**: Policies targeting `kasten-io` namespace (like `k10-disaster-recovery-policy`)
- **System report policies**: `k10-system-reports-policy` (has empty selector)
- **Custom exclusions**: Policies listed in `EXCLUDE_POLICIES` environment variable

### Dry Run Mode

- **Preview changes** before applying
- **Validate selector logic** 
- **Verify kubectl access** and permissions
- **Generate migration report** 

### Validation Report

After migration, the script provides a comprehensive report showing:
- ✅ **VM scoped policies** (`k10.kasten.io/virtualMachineRef`)
- • **Namespace scoped policies** (`k10.kasten.io/appNamespace`) 
- ❓ **Unknown scope policies** (other selector types)

## Troubleshooting

### Common Issues

**Permission Denied:**
```bash
Error: policies.config.kio.kasten.io "policy-name" is forbidden
```
- Ensure kubectl context has proper RBAC permissions
- Verify access to `kasten-io` namespace

### Debug Commands

Check current policy status:
```bash
kubectl get policies.config.kio.kasten.io -n kasten-io -o custom-columns="NAME:.metadata.name,SELECTOR:.spec.selector.matchExpressions[0].key,VALUE:.spec.selector.matchExpressions[0].values[0]"
```

View specific policy:
```bash
kubectl get policies.config.kio.kasten.io <policy-name> -n kasten-io -o yaml
```

## Script Behavior

### Discovery Logic

1. Finds all policies in `kasten-io` namespace
2. Filters for policies with `k10.kasten.io/appNamespace` selector key
3. Processes each policy individually

### Migration Logic

For each eligible policy:

1. **Check custom exclusions**: Skip if policy name is in `EXCLUDE_POLICIES`
2. **Check system exclusions**: Skip if policy is `k10-system-reports-policy`
3. **Extract current namespace value** from selector
4. **Check value-based exclusion criteria**:
   - Skip if value is `kasten-io-cluster` 
   - Skip if value is `kasten-io`
5. **Apply JSON patch** to update:
   - Selector key: `k10.kasten.io/appNamespace` → `k10.kasten.io/virtualMachineRef`
   - Selector value: `<namespace>` → `<namespace>/*`
   - Remove `spec.actions[1].exportParameters/migrationToken`
   - Remove `spec.actions[1].exportParameters/receiveString`
4. **Report success/failure**

### Validation Logic

After migration:
1. **Query all policies** in namespace
2. **Categorize by selector key**:
   - VM scoped: `k10.kasten.io/virtualMachineRef`
   - Namespace scoped: `k10.kasten.io/appNamespace`  
   - Unknown: Any other key
3. **Generate summary report**
