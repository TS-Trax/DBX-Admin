
# ==============================================================================================
# Databricks Admin GUI Tool - Databricks-specific functions
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================

# Read from file and create vars 
$config = Get-Content -Path .\files\dbx-admin-config.txt 
$config | Where-Object {$_.length -gt 0} | Where-Object {!$_.StartsWith("#")} | ForEach-Object{
    $var = $_.Split('=',2).Trim()
    # Prevent 'var already exists' error 
    if (Get-Variable $var[0] -Scope 'Global' -ErrorAction 'Ignore') {
        Set-Variable -Name $var[0] -Value $var[1]
    } else {
        New-Variable -Name $var[0] -Value $var[1]
    }
}

$reading = "Reading from dbx-admin-config: "
$reading += "'" + $vaultName  + "'" + ", '" 
$reading += $workspaceFilter + "'" + ", '" 
$reading += $workspaceFilterOut + "'" + ", '" 
$reading += $workspaceRegion + "'" + ", '" 
$reading += $workspaceRegion_2 + "'"  + ", '" 
$reading += $subscriptionFilter + "'" 


Write-Host $reading


# Defensive programming ---------------------------------
function not_set( $thing ){
    return  [string]::IsNullorWhiteSpace($thing)  
}

if( not_set $workspaceFilter){
    $workspaceFilter = '*'       # If empty, match all
}
if( not_set $workspaceFilterOut){
    $workspaceFilterOut = 'zzzz'  # If empty, exclude none
}
if( not_set $workspaceRegion){
    $workspaceRegion = 'northeurope'
}
if( not_set $subscriptionFilter){
    $subscriptionFilter = '*'       # If empty, match all
}
# --------------------------------------------------------

$global:KV = $vaultName
$global:FILTER = $workspaceFilter           
$global:FILTER_OUT = $workspaceFilterOut.split(',') # Multiple exclude filters 
$global:REGION = $workspaceRegion
$global:REGION_2 = $workspaceRegion_2
$global:SUB_FILTER = $subscriptionFilter 

#------------------------------------------------------------------------------------------------------------------------------------------------


Import-Module DatabricksPS -Force
Import-Module -Name azure.databricks.cicd.tools -Force

# To occasionnally update the modules we're using
# Update-Module DatabricksPS -Force
# Update-Module -Name azure.databricks.cicd.tools -force

$ApiUrl = 'https://'   + $global:REGION + '.azuredatabricks.net'
$ApiUrl_2 = 'https://' + $global:REGION_2 + '.azuredatabricks.net'

# -------------------------------------------------------------------------

$global:SEL_REGION # 

#-------------------------------------
# Cache each dbx region
$global:dbxRegions = @{}
function get-Region($dbx){

    #Write-Host ('Retrieving region for workspace: ' + $dbx)

    if( $global:dbxRegions.ContainsKey($dbx) ){
        #Write-Host ('Retrieving region from cache: ' + $global:dbxRegions[$dbx])
        return $global:dbxRegions[$dbx]
    }
    else{
        $res = Get-AzResource -ResourceType 'Microsoft.Databricks/workspaces' |  
                                Where-Object Name  -eq $dbx

        #Write-Host ('Retrieving region - cache miss: ' + $res.Location)                        
        $global:dbxRegions.add($dbx, $res.Location)
        return $res.Location
    }
}

# -------------------------------------
# Set DBX env for both Databricks modules
function set-DbxEnvAny($token, $dbx){
    if($null -eq $token -or $null -eq $dbx){
        Write-Host "Need both workspace and token to set up the Databricks environment"
        return
    }
    Write-Host ("Setting DBX env. for DatabricksPS package with workspace " + "'"  + $dbx + "'")
    Write-Host ("Connecting DBX env. for cicd.tools package with workspace " + "'" + $dbx + "'")

    $region = get-Region $dbx
    Write-Host ( $dbx + " Region in setEnv: " + $region) 

    if( $region -eq $global:REGION_2 ){
        Set-DatabricksEnvironment -AccessToken $token -ApiRootUrl $ApiUrl_2       # DatabricksPS module
        Connect-Databricks -BearerToken $token -Region  $global:REGION_2          # databricks.cicd.tools module
        $global:SEL_REGION =  $global:REGION_2
    }
    else{
        Set-DatabricksEnvironment -AccessToken $token -ApiRootUrl $ApiUrl          # DatabricksPS module
        Connect-Databricks -BearerToken $token -Region $global:REGION              # databricks.cicd.tools module
        Write-Host $global:REGION 
        $global:SEL_REGION = $global:REGION 
    }
}

# -------------------------------------
function get-AllDBKS(){
    
   # Multiple filters ---------------------------------------------
    $allWs = Get-AzResource -ResourceType 'Microsoft.Databricks/workspaces' 
    $resultsIn = @()
    $global:FILTER | ForEach-Object{
        $resultsIn += ( $allWs|  Where-Object Name  -Like $_ )
    }
    $results = @()
    $count = 1
    $global:FILTER_OUT | ForEach-Object{
        if($count -eq 1){
            $results = ( $resultsIn |  Where-Object Name  -NotLike $_.Trim() )
            $count = $count + 1
        }
        else{
            $results = ( $results |  Where-Object Name  -NotLike $_.Trim() )
        }
    }
   return $results; 
}

# -------------------------------------
function get-AllDBKSnames(){

    $alldbks = get-AllDBKS 
    $alldbksNames = @()
    $alldbksNames.Clear()
    $alldbks | ForEach-Object{
        
      $alldbksNames += $_.Name
    }
    return $alldbksNames  | Sort-Object
}

# --------------------------------------
function get-DbxGroups($dbx){

    $tk = $dbksTokens[$dbx] 
    #write-Host ("TOKEN FOR " + $sel + ": " + $tk)
    $region = get-Region $dbx
    #Write-Host ( $dbx + " Region in get groups: " + $region) 
    # GROUPS
    if($region -eq $global:REGION_2 ){ # TEMP
        Get-DatabricksGroups -BearerToken $tk -Region  $global:REGION_2  -ErrorAction SilentlyContinue  | Sort-Object
    }
    else{
        Get-DatabricksGroups -BearerToken $tk -Region $global:REGION -ErrorAction SilentlyContinue  | Sort-Object
    }
}

$global:subList = @() # CACHE
function getSubscriptions{
    if( $global:subList.Count -eq 0){
        $subs = Az.Accounts\Get-AzSubscription | Where-Object Name  -Like $global:SUB_FILTER
        foreach($s in $subs){
            $global:subList += $s.Name
        }
    }
    return $global:subList
}


# TEST 
#get-AllDBKSnames
#getSubscriptions
