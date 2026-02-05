# Nightly RG cleanup (Automation Account)

This runbook deletes all resource groups in subscription `86a1d32d-b0bb-42bf-a08d-b1eb8aa7a774` except those listed in `$excludedRgs`.

## Prereqs
- Azure subscription with permission to create an Automation Account
- `az` CLI installed (optional if you use the portal)

## Deploy (portal)
1. Create an **Automation Account**.
2. Enable **System-assigned managed identity**.
3. Assign the managed identity **Contributor** (or **Resource Group Contributor**) at the subscription scope.
4. Create a **PowerShell** runbook and paste in `rg-cleanup-runbook.ps1`.
5. Create a **schedule**:
   - Start time: **23:59**
   - Time zone: **Europe/London**
   - Recurrence: **Daily**
6. Link the schedule to the runbook.

## Deploy (CLI)
Set variables (edit as needed):
```
RG_NAME="rg-lw-aa-cleanup"
AA_NAME="aa-rg-cleanup"
LOCATION="westeurope"
SUB_ID="86a1d32d-b0bb-42bf-a08d-b1eb8aa7a774"
SCHEDULE_NAME="aa-sch-2359-clean"
RUNBOOK_NAME="rg-cleanup"
RUNBOOK_PATH="/workspaces/ANS-AI-Stack-In-A-Day-DIN/_backend/automation/rg-cleanup-runbook.ps1"
```

Set Azure CLI defaults (avoids extension prompts):
```
az config set extension.use_dynamic_install=yes_without_prompt
az account set --subscription "$SUB_ID"
```

Create Automation Account and enable identity:
```
az group create -n "$RG_NAME" -l "$LOCATION"
az automation account create -g "$RG_NAME" -n "$AA_NAME" -l "$LOCATION"
az resource update -g "$RG_NAME" -n "$AA_NAME" --resource-type "Microsoft.Automation/automationAccounts" --set identity.type=SystemAssigned
```

Assign role to the managed identity at subscription scope:
```
PRINCIPAL_ID=$(az automation account show -g "$RG_NAME" -n "$AA_NAME" --query identity.principalId -o tsv)
az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --role Contributor --scope "/subscriptions/$SUB_ID"
```

Create runbook and upload script:
```
az automation runbook create -g "$RG_NAME" --automation-account-name "$AA_NAME" -n "$RUNBOOK_NAME" --type PowerShell
az automation runbook replace-content -g "$RG_NAME" --automation-account-name "$AA_NAME" -n "$RUNBOOK_NAME" --content @"$RUNBOOK_PATH"
az automation runbook publish -g "$RG_NAME" --automation-account-name "$AA_NAME" -n "$RUNBOOK_NAME"
```

Create schedule and link it:
```
az automation schedule create -g "$RG_NAME" --automation-account-name "$AA_NAME" -n "$SCHEDULE_NAME" --frequency Day --interval 1 --start-time "2026-02-06T23:59:00" --time-zone "Europe/London"
az automation job schedule create -g "$RG_NAME" --automation-account-name "$AA_NAME" --runbook-name "$RUNBOOK_NAME" --schedule-name "$SCHEDULE_NAME"
```

## Exclusions
Edit the `$excludedRgs` array in `rg-cleanup-runbook.ps1` to add or remove RG names. Defaults include `rg-lw-aa-cleanup` and `NetworkWatcherRG` to prevent self-deletion and keep Azure network watcher resources.

## Safety notes
- This deletes resource groups and all resources inside them.
- Keep at least one admin RG excluded if you need stable shared services.
