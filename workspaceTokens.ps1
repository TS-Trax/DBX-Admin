# ==============================================================================================
# Databricks Admin GUI Tool - Databricks Tokens processing to/from Key Vault
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================

# ALL Databricks tokens 
# Set/get the tokens from key vaults, e.g.:
# Get-AzKeyVaultSecret -VaultName 'kv-xxxx' -Name 'secret1'

Import-Module Az.KeyVault
Import-Module .\screen.ps1 -Force
Import-Module .\common.ps1 -Force
Import-Module .\dbx-functions.ps1 -Force

Write-Host ("Saved from dbx-admin-config: " + "'" +  $global:FILTER + "'" )

function Set-DbxToken($wsp){
    $kv = $global:KV 
    $tk = $wsp + "-tk"
    $secretvalue = ConvertTo-SecureString $dbksTokens[$wsp] -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $kv -Name $tk -SecretValue $secretvalue
  }
  
  function Get-DbxToken($wsp){
    $kv = $global:KV 
    $tk = $wsp + "-tk"
    Get-AzKeyVaultSecret -VaultName $kv -Name $tk -AsPlainText -ErrorAction SilentlyContinue  
  }


# Get the DBX + tokens from KV ----------------------------------------------------

$dbksTokens = @{}
$allDbx = @()

if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) {
  Connect-AzAccount
}
# Automatically save the context for the next sign-in. Default scope is CurrentUser. Context is shared by all jobs.
Enable-AzContextAutosave

$window_splash.Show() ##############################

show_progress #---------
$Win.Title = "Retrieving tokens for all workspaces..."

$subs = getSubscriptions
Foreach ($sub in $subs){
  Set-AzContext -SubscriptionName $sub
  $Win.Title = "Getting in " + $sub.Name + "..."
  $allDbx = get-AllDBKSnames
  $Win.Title = "Retrieving tokens from Key Vault..."
  $allDbx | ForEach-Object{
    Write-Host ("Getting token for " + $_)
    $Win.Title = "Token for " + $_ + "..."
    $tk = Get-DbxToken($_)
    $dbksTokens.add( $_,  $tk )
  }
}

hide_progress #---------
start-sleep -Milliseconds 500
$window_splash.Hide()  ##############################

<# Store all in KV  before removing hard-coded tokens in this file - One-time operation
foreach ($h in $dbksTokens.GetEnumerator()) {
  Set-DbxToken($h.Name)
}
#>
#Write-Host -ForegroundColor Cyan  ( "Registered workspaces:" )
#$dbksTokens | Format-Table -AutoSize 
#Write-Host -ForegroundColor Cyan  ( " Please register workspaces not listed above." )



