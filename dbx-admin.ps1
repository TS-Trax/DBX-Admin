# ==============================================================================================
# Databricks Admin GUI Tool - Main Window
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================


# ----------------LOGIN-------------------------------------------------------------
$IS_DEV = $false

if($IS_DEV -eq $false){

    # PRODUCTION SETUP - Display login page every time 
    Write-Host '____________Prod Setup_____________'
    Connect-AzAccount  
}
else{

    # DEV setup - Save login creds to avoid login everytime -If passw changed, need to re-run login
    # This command connects to Azure with an authenticated account - UNCOMMENT & RE_RUN IF PASSWORD CHANGED!
    #Connect-AzAccount
    Write-Host '____________Dev Setup_______________'

    if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) {
        Connect-AzAccount
    }
    # Automatically save the context for the next sign-in. Default scope is CurrentUser. Context is shared by all jobs.
    Az.Accounts\Enable-AzContextAutosave
}

# This command connects the current PowerShell session to an Azure Active Directory tenant. Only use if previous command does not work. 
# Connect-AzureAD




# ----------------WPF-XAML WINDOW UI-------------------------------------------------------------

Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms

$xamlFile = '.\files\MainWindow.xaml'

#create window
$inputXML = Get-Content $xamlFile -Raw -Force
$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$xaml = $inputXML

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $window = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'

$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}
Get-Variable var_*  | Out-Null


# IMAGES - source in XAML not working with Powershell
$var_dbxLogo.Source   = ".\files\dbks.png"
$var_adminLogo.Source = ".\files\admin.png"
$var_kvClick.Source = ".\files\kv.png"
$var_vmClick.Source = ".\files\VM.png"

# Only allow minimizing the window, not resizing it
$window.resizeMode = 'CanMinimize'


# --------------- Progress Indicator window ----------------------------

$Win = New-object System.Windows.Window
$Win.WindowStartupLocation = "CenterScreen"
$Win.Title = "Processing..."
$Win.Width = 300       
$Win.Height = 20       
$Win.WindowStyle = "ToolWindow"
$Win.Show()
$Win.Hide()

function show_progress(){
    $Win.Show()
}
function hide_progress(){
    $Win.Hide()
}


#---------------------------------MODULES CHECK ------------------------------------------------------------

<# --------------------------------------
.SYNOPSIS
Check if specific module is installed/imported, and if not, install/import.
#>
function Load-Module ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        Write-Host "Module $m is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m -Force #-Verbose
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force  -Scope CurrentUser #-Verbose
                Import-Module $m -Force #-Verbose
            }
            else {

                # If module is not imported, not available and not in online gallery then abort
                Write-Host "Module $m not imported, not available and not in online gallery. Aborting."
                #EXIT 1
            }
        }
    }
}


# -------------------------------------------
function inform ($msg){
    Write-Host $msg
    $Win.Title = $msg  
}


# -------------------------------------------
function getModule($m){
    try{
        Import-Module $m -Force
    }
    catch{
        inform ("Checking module " + $m + "...")
        Load-Module $m
    }
}


#----------------------------------------------
show_progress
$Win.Title = "Setting up modules. Please wait..."
#-----------------------------------------------
getModule  DatabricksPS  
getModule  azure.databricks.cicd.tools  
getModule Communary.PASM 
getModule  Az.Accounts
getModule  Az.Resources
getModule  Az.KeyVault
#-----------------------------------------------
hide_progress

# These are our own modules
Import-Module .\common.ps1 -Force
Import-Module .\dbx-functions.ps1 -Force
Import-Module .\workspaceTokens.ps1 -Force

# To occasionnally update the modules we're using
# Update-Module DatabricksPS -Force
# Update-Module -Name azure.databricks.cicd.tools -force

# The following might be necessary in case of errors (conflicts) - remove all the old AzureRm modules - only use the new Az ones
# Uninstall-AzureRm

# ---------------------------------------------------------------------------------------


# Global dynamic vars 
$global:selWks   = $null
$global:selGrp   = $null
$global:allGrps  = $null
$global:selUsr   = $null
$global:noGrp    = $null
$global:dbxUsers = $null
# -------------------------------------
function printGlobals(){
   Write-Host "GLOBAL VARS:"
   Write-Host ("Workspace: " + $global:selWks)
   Write-Host ("Selected Group: " + $global:selGrp)
   Write-Host ("Selected user: " + $global:selUsr)
   Write-Host ("All workspace groups: " + $global:allGrps)
   Write-Host ("Stand-alone users: " + $global:noGrp)
   Write-Host ("All workspace users: " + $global:dbxUsers)
}

# --------------------------------------
function set-DbxEnv($token){
    set-DbxEnvAny $token $global:selWks
}

# --------------------------------------
function show_workspaces($sub){
    Set-AzContext -SubscriptionName $sub
    $list = get-AllDBKSnames
    $list | ForEach-Object { 
        if( ! $var_WList.Items.Contains($_)){
            [void] $var_WList.Items.Add($_) 
            #Write-Host $_
        }
    }
}


# --------------------------------------
function show_groups($sel){
    [void] $var_GList.Items.clear()
    #Write-Host ($sel)
    if( ! $dbksTokens[$sel] ){
        $msg = "No token found for '" +  $sel + "'. Create a token for this workspace and store it in the Key Vault '" + $global:KV + "'."
        showErrMsg($msg)
    }
    else{
        $glist = get-DbxGroups($sel)
        $global:allGrps = $glist
        $glist | ForEach-Object { 
            if( ! $var_GList.Items.Contains($_)){
                [void] $var_GList.Items.Add($_) 
                #Write-Host $_
            }
        } 
    }
}

# -------------------------------------
function show_members($sel){
    [void] $var_UList.Items.clear()
    $global:selGrp = $sel
    #Write-Host ($global:selGrp)
    if($sel){ 
        $uList =  Get-DatabricksGroupMembers -GroupName $sel | 
                        Select-Object -ExpandProperty user_name -ErrorAction SilentlyContinue | Sort-Object
        $uList | ForEach-Object { 
            if( IsValidEmail($_) -and ! $var_UList.Items.Contains($_)){
                [void] $var_UList.Items.Add($_) 
                #Write-Host $_
            }
        } 
    }
}

# -------------------------------------
function show_users($dbks){
    $tk = $dbksTokens[$dbx]

    #Invoke directly - No avail method to get the user IDs
    $res = Invoke-DatabricksAPI -BearerToken $tk -API "api/2.0/preview/scim/v2/Users" -Method GET

    $users = [ordered] @{}
    $IDs = $res.Resources.id
    $NAMES = $res.Resources.userName

    $idx = 0
    $IDs | ForEach-Object {
        #Write-Host("Adding Name " + $NAMES[$idx] + " with ID " + $_)
        $users.add( $NAMES[$idx], $_ )
        $idx +=1
    }   
    $global:dbxUsers = $users
    return $users;
}

# -------------------------------------
function show_standalone_users ($dbx){
    $tk = $dbksTokens[$dbx]
    set-DbxEnvAny $tk $dbx
    $lonerList = @()

    $users = show_users($dbks)
    $userNames = $users.keys

    $userNames | ForEach-Object{
        try{
            $groups = Get-DatabricksGroupMembership -Username $_
            if($groups.Count -eq 0){
                Write-Host("Lone user: " + $_ )
                $lonerList += $_
            }
        }
        catch [Exception]{
            Write-Debug $_
        }
    }
    return $lonerList
}


## -------------------------- WORKSPACES -----------------------------------------------------------------------------

try{    
    $subs = Az.Accounts\Get-AzSubscription
    Foreach ($sub in $subs){ $var_Subscr.Items.Add($sub.Name);}
}
catch{
    Write-Host 'Could not get subscriptions. Prompting to login.'
    # Probably need to login 
    Connect-AzAccount
}

$var_Subscr.Add_SelectionChanged({

    show_progress
    $Win.Title = "Retrieving workspaces..."
    $sel = $var_Subscr.SelectedItem
    show_workspaces($sel)  
    hide_progress
})


## ------------------------------- USERS & GROUPS-------------------------------------------------------------------------


$var_WList.Add_SelectionChanged({

    show_progress
    $Win.Title = "Retrieving groups..."
    $sel = $var_WList.SelectedItem
    $global:selWks  = $sel
    show_groups($sel)
    hide_progress
})

# GROUP MEMBERS   
$var_GList.Add_SelectionChanged({

    show_progress
    $Win.Title = "Retrieving users..."
    $sel = $var_GList.SelectedItem
    show_members($sel)
    if( -not [string]::IsNullOrEmpty($sel) ){
        $global:selGrp = $sel
        Write-Host ($global:selGrp)
        [void] $var_CurrentGroup.clear()
        $var_CurrentGroup.AddText($sel)
    }
    hide_progress
})

$var_UList.Add_SelectionChanged({

    $sel = $var_UList.SelectedItem
    $global:selUsr = $sel
    if( -not [string]::IsNullOrEmpty($sel) ){
        Write-Host ($global:selUsr)
        [void] $var_CurrentUser.clear()
        $var_CurrentUser.AddText($sel)
    }
})


# CLEAR ALL LISTINGS --
<#
$var_ClearLists.Add_Click({

    try{
        [void] $var_UList.Items.clear()
        [void] $var_GList.Items.clear()
        [void] $var_WList.Items.clear()
    }
    catch [Exception]{
        Write-Debug $_
    }

})
#>

#------------------------------------------ FIND/ADD/REMOVE USERS --------------------------------------------------------------------


# FIND USER _________________________________________________________________

$var_Find.Add_Click( {

    $usr = get_text $var_CurrentUser

    if( [string]::IsNullOrEmpty($usr) ){
        $msg = "Nothing to Find"
        showErrMsg ($msg)
        return;
    }
    elseif( -not (IsValidEmail($usr)) ){
        $msg = "Enter correct email format"
        showErrMsg ($msg)
        return;
    }
    try{
        show_progress
        $Win.Title = "Finder user..."
        Write-Host ("Searching for user " + $usr + " across all workspaces in all subscriptions")
        #  Get all Dbx 
        $allDbx = @()
        $Win.Title = "Retrieving subscriptions..."
        $sub = Get-AzSubscription
        Write-Host ("Subs: " + $sub)
        $Win.Title = "Retrieving workspaces in each subscription..."
        foreach($s in $sub){
            Get-AzSubscription -SubscriptionName $s.Name | Set-AzContext
            $allDbx += get-AllDBKSnames
        }
        Write-Host ("Retrieved  " + $allDbx.Count + " workspaces from all subs")
        # Search for memberships in each Dbx
        $memberships = @{}
        $Win.Title = "Retrieving membership in each workspace..."
        foreach($dbx in $allDbx){
            $tk = $dbksTokens[$dbx]
            set-DbxEnvAny $tk $dbx
            try{
                $groups = Get-DatabricksGroupMembership -Username $usr 
                Write-Host ("Membership in  " + $dbx + ": " + $groups)
                $memberships[$dbx] = $groups
            }
            catch [Exception]{
                Write-Debug $_
                continue;
             }
        }
        hide_progress
        if($memberships.Count -eq 0){
            showMsg ("User " + $usr + " not found." )
            return;
        }
        else{
            <# Works but formatting problems
            $columns = @{Expression={$_.Name};Label="Workspace";width=30}, @{Expression={$_.Value};Label="Membership";width=30}
            $output = $memberships.GetEnumerator() | Sort-Object Name | Format-Table $columns | Out-String
            showMsg ("User " + $usr + " found in: " + $output)
             showMsg ($output)
            #>
            $title = $usr + " Memberships" 
            $memberships.GetEnumerator() | 
                    Select-Object @{l='Workspace';e={$_.Key}},@{l='Groups';e={$_.Value}} |  Out-GridView -Title $title
           
            return;
        }
    }
    catch [Exception]{
        Write-Debug $_
        showErrMsg  $_
        return;
     }

})

# ADD USER _________________________________________________________________

$var_Add.Add_Click( {

    $group = $global:selGrp  
    $dbks  = $global:selWks
    $tk    = $dbksTokens[$dbks]
    set-DbxEnv($tk)
    printGlobals
    $usr = get_text $var_CurrentUser

    $existingUsers = Get-DatabricksGroupMembers -GroupName $group | 
                        Select-Object -ExpandProperty user_name -ErrorAction SilentlyContinue

    if( [string]::IsNullOrEmpty($usr) ){
        $msg = "Nothing to Add"
        showErrMsg ($msg)
        return;
    }
    elseif( -not (IsValidEmail($usr)) ){
        $msg = "Enter correct email format"
        showErrMsg ($msg)
        return;
    }
    elseif( $null -eq $dbks -or  $null -eq $group ){
        $msg = "Please select both workspace and group"
        showErrMsg ($msg)
        return;
    }
    elseif( $existingUsers -and $existingUsers.Contains($usr) ){
        $msg = "User " + $usr + " already exists in group " + $group + "!"
        showErrMsg ($msg)
        return;
    }
    else{
        $msg = "Add user '" + $usr + "' to group " + $group + " in " + $dbks + "?"
        if( -not (showConfirmDialog  $msg) ){
            return;
        }
        else{ # ADD USER ----------------------------------------------------------------
            try{
                Write-Host ("Adding user '" + $usr + "' to group " + $group + " in  " + $dbks)
                # This is from the cicd.tools module. No equiv. in the DatabricksPS package.
                # If the user already exists the error will be ignored, but the entitlments and groups- if requested - will not be applied
                # So do not use this method to assign to groups, only to add to the workspace.
                # ATT.: This allows to add any email (e.g. 'nobody@domain.com') without checking with Azure AD
                Add-DatabricksUser -BearerToken $tk -Username $usr 

                # Use this method to add to Group
                Add-DatabricksGroupMember -UserName $usr -ParentGroupName $group
                $var_UList.Items.Add($usr)
                showMsg ("User '" + $usr + "' added to group " + $group + " in  " + $dbks)
                return;
            }
            catch [Exception]{
                Write-Debug $_
                showErrMsg  $_
                return;
             }
        }
    }
  
})


# REMOVE USER ______________________________________________________

$var_Remove.Add_Click( {

    $group = $global:selGrp  
    $dbks  = $global:selWks
    $tk    = $dbksTokens[$dbks]
    set-DbxEnv($tk)
    printGlobals; #Write-Host("TOKEN: " + $tk)
    $usr = get_text $var_CurrentUser

    if( [string]::IsNullOrEmpty($usr) ){
        $msg = "Nothing to Remove"
        showErrMsg ($msg)
        return;
    }
    elseif( $null -eq $dbks -or  $null -eq $group -or $null -eq $usr){
        $msg = "Please select ALL of workspace, group and user"
        showErrMsg ($msg)
        return;
    }
    elseif( -not (IsValidEmail($usr)) ){ # Should NOT happen, as only valid emails were allowed in show_users
        $msg = "Not an email format. Most likely a Service Principal, which is essential for mounting the Data Lake. "
        $msg += "If you MUST remove it, switch to manual mode."
        showErrMsg ($msg)
        return;
    }

    # Show user's group memberships in confirm dialog
    $usr_groups = Get-DatabricksGroupMembership -Username $usr 
    $msg = "Remove user " + $usr+ " from group " + $group+ " in " + $dbks + "?"
    $msg += "`n Membership: "   
    $msg +=  $usr_groups
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    else{ # REMOVE USER ------------------------------------------------------------------
        try{
            # Using the DatabricksPS package as the cicd.tools one is not always working, e.g. for removing users
            Write-Host ("Removing user " + $usr + " from group " + $group + " in  " + $dbks)
            Remove-DatabricksGroupMember -UserName $usr -ParentGroupName  $group
            $var_UList.Items.Remove($usr)
            showMsg ("User " + $usr + " removed from group " + $group + " in  " + $dbks)
            return;
        }
        catch [Exception]{
            Write-Debug $_
            showErrMsg  $_
            return;
        }
    }
})


#------------------------------------------ ADD/REMOVE GROUPS --------------------------------------------------------------------

# ADD GROUP _________________________________________________________________

$var_AddG.Add_Click( {

    $dbks  = $global:selWks
    $tk    = $dbksTokens[$dbks]
    set-DbxEnv($tk)
    printGlobals
    $grp = get_text $var_CurrentGroup
    $existingGrps = Get-DatabricksGroups -BearerToken $tk 

    if( [string]::IsNullOrEmpty($grp) ){
        $msg = "Nothing to Add"
        showErrMsg ($msg)
        return;
    }
    elseif( $existingGrps -and $existingGrps.Contains($grp) ){
        $msg = "Group " + $grp + " already exists in workspace " + $dbks + "!"
        showErrMsg ($msg)
        return;
    }
    else{
        $msg = "Add group '" + $grp + "' to workspace " + $dbks + "?"
        if( -not (showConfirmDialog  $msg) ){
            return;
        }
        else{ # ADD GROUP ----------------------------------------------------------------
            try{
                Write-Host ("Adding group '" + $grp + "' to workspace " + $dbks)
                Add-DatabricksGroup -BearerToken $tk -GroupName $grp
                $var_GList.Items.Add($grp) 
                showMsg ("Group '" + $grp + "' added to workspace " + $dbks)
                return;
            }
            catch [Exception]{
                Write-Debug $_
                showErrMsg  $_
                return;
             }
        }
    }
  
})


# REMOVE GROUP _________________________________________________________________

$var_RemoveG.Add_Click( {

    $dbks  = $global:selWks
    $tk    = $dbksTokens[$dbks]
    set-DbxEnv($tk)
    printGlobals
    $grp = get_text $var_CurrentGroup
    $existingGrps = Get-DatabricksGroups -BearerToken $tk 

    if( [string]::IsNullOrEmpty($grp)){
        $msg = "Nothing to Remove"
        showErrMsg ($msg)
        return;
    }
    elseif( $existingGrps -and ! $existingGrps.Contains($grp) ){
        $msg = "Group " + $grp + " does not exist in workspace " + $dbks + "!"
        showErrMsg ($msg)
        return;
    }
    else{
        $info = ""
        $uList =  Get-DatabricksGroupMembers -GroupName $grp | 
                        Select-Object -ExpandProperty user_name -ErrorAction SilentlyContinue | Sort-Object
        if( !$uList){
            $info += "`n NOTE: Group is empty"
        }
        else{
            $info += "`n NOTE: Group is NOT empty. " 
            $info += "`n It is recommended to first COPY the group to another workspace as a backup/restore option."
            $info += "`n `n Proceed anyway?"
            <#
            $info += "  NOTE - Group members: " 
            $uList | ForEach-Object { 
                $info += "; " + $_
            } 
            #>
        }
        $msg = "Remove group" + $grp + " from workspace " + $dbks + "?" + $info
        if( -not (showConfirmDialog  $msg) ){
            return;
        }
        else{ # REMOVE GROUP ----------------------------------------------------------------
            try{
                Write-Host ("Removing group " + $grp + " from workspace " + $dbks)
                Remove-DatabricksGroup -BearerToken $tk -GroupName $grp
                $var_GList.Items.Remove($grp) 
                showMsg ("Group " + $grp + " removed from workspace " + $dbks)
                return;
            }
            catch [Exception]{
                Write-Debug $_
                showErrMsg  $_
                return;
             }
        }
    }
  
})

# COPY GROUP _________________________________________________________________

$var_CopyG.Add_Click({

    $dbks  = $global:selWks
    if( $null -eq $dbks ){
        $msg = "Select a workspace to view its groups."
        showErrMsg ($msg)
        return;
    }
    $tk    = $dbksTokens[$dbks]
    set-DbxEnv($tk)
    printGlobals
    $grp = get_text $var_CurrentGroup
    $existingGrps = Get-DatabricksGroups -BearerToken $tk 

    if( [string]::IsNullOrEmpty($grp)){
        $msg = "Nothing to Copy"
        showErrMsg ($msg)
        return;
    }
    elseif( $existingGrps -and ! $existingGrps.Contains($grp) ){
        $msg = "Group " + $grp + " does not exist in workspace " + $dbks + "!"
        showErrMsg ($msg)
        return;
    }
    else{
        Import-Module ./copy-group.ps1 -Force
    }

})



# ------------------------------------------- OUTSIDERS DIALOG & WINDOW -------------------------------------------------------------

$var_ViewOutsiders.Add_Click({
    
    $dbks = $global:selWks
    if( $null -eq $dbks ){
        showErrMsg("Select a workspace to view its stand-alone users.")
        return;
    }
    $sel = $global:selWks 
    show_progress
    $Win.Title = "Checking for outsiders..."
    $global:noGrp = show_standalone_users($sel)
    hide_progress

    if($noGrp.Count -ne 0){
        $columns = @{Expression={$_.Name};Label="user";width=50}
        $output = $noGrp | Sort-Object | Format-Table $columns | Out-String

        $msg = "The following users do not belong to any group in workspace '"+ $sel 
        $msg += "'. Either remove them of add them to a group: `n`n" + $output + "`n`nClean up now?"
        if( -not (showConfirmDialog  $msg) ){
            return;
        }
        else{ 
            Write-Host("Will process outsiders now.")
            # Outsider processing window
            Import-Module ./outsiders.ps1 -Force
        }
    }
    else{
        showMsg("No outsiders detected in workspace "+ $sel +". All users are group members.")
    }
})


#------------------------------------------- CLUSTERS WINDOW -------------------------------------------------------------------

$var_ViewJobs.Add_Click( {

    $dbks = $global:selWks
    if( $null -eq $dbks ){
        $msg = "Select a workspace to view its Jobs & Clusters."
        showErrMsg ($msg)
        return;
    }
    Import-Module ./jobs-clusters.ps1 -Force
})



#------------------------------------------- SECURITY WINDOW (Key Vault) ----------------------------------------------------

$var_kvPin.Add_Click( {

    Import-Module ./security.ps1 -Force
})

#-----------------------------------------------VM instance types (Show in GridView )-------------------------------------------
$var_vmPin.Add_Click( {

    $dbks = $global:selWks
    if( $null -eq $dbks ){
        $msg = "Select a workspace to view the available VM instance types."
        showErrMsg ($msg)
        return;
    }
    $tk    = $dbksTokens[$dbks]
    set-DbxEnv($tk)

    $vmList = azure.databricks.cicd.tools\Get-DatabricksNodeTypes -BearerToken $tk -Region $global:SEL_REGION
    #$vmList | Out-GridView
    $title = "Available VM instance types - " + $global:SEL_REGION
    $vmList | Select-Object -Property node_type_id, memory_mb, num_cores, category, num_gpus,`
                                        is_io_cache_enabled, photon_worker_capable, photon_driver_capable | 
              Sort-Object -Property node_type_id | Out-GridView -Title $title

})




#------------------------------------------- WORKSPACE WINDOW -------------------------------------------------------------------

$var_accessWs.Add_Click( {

    $dbks = $global:selWks
    if( $null -eq $dbks ){
        $msg = "Select a workspace to view its folders."
        showErrMsg ($msg)
        return;
    }
    Import-Module ./workspaces.ps1 -Force
})



#------------------------------------------- BULK OPS WINDOW -------------------------------------------------------------------

$var_ViewBulk.Add_Click( {

    Import-Module ./bulk-ops.ps1 -Force
})

#------------------------------------------------------------------------------------------------------------------------------




# All code before this  
$Null = $window.ShowDialog()



