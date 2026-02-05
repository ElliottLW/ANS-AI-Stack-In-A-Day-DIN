# Requires Az.Accounts, Az.Resources
# Runbook to delete all resource groups except excluded names.

Connect-AzAccount -Identity

$subscriptionId = "86a1d32d-b0bb-42bf-a08d-b1eb8aa7a774"
Set-AzContext -Subscription $subscriptionId

# RGs to keep (case-insensitive)
$excludedRgs = @(
    "rg-lw-aa-cleanup",
    "NetworkWatcherRG"
)

Get-AzResourceGroup | Where-Object {
    $excludedRgs -notcontains $_.ResourceGroupName
} | ForEach-Object {
    $rgName = $_.ResourceGroupName
    Write-Output "Deleting RG: $rgName"
    Remove-AzResourceGroup -Name $rgName -Force -AsJob
}
