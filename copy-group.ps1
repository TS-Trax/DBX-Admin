# ==============================================================================================
# Databricks Admin GUI Tool - Databricks WQorkspaces Window
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================

Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms

$xamlFile_cg = '.\files\CopyGroup.xaml'

#create window
$inputXML_cg = Get-Content $xamlFile_cg -Raw -Force
$inputXML_cg = $inputXML_cg -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$xaml_cg = $inputXML_cg

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml_cg)
try {
    $window_cg = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'

$xaml_cg.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window_cg.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}
Get-Variable var_* | Out-Null

#----------------------------------------------------------------------------------------------
# IMAGES - source in XAML not working with Powershell
$var_dbxLogo.Source   = ".\files\dbks.png"

# Only allow minimizing the window, not resizing it
$window_cg.resizeMode = 'CanMinimize'

#Import-Module .\common.ps1 -Force
#Import-Module .\dbx-functions.ps1 -Force


# Dynamic vars 
$global:SEL_GRP = $null
$global:SEL_WS = $null
$global:TK = $dbksTokens[$dbks]
set-DbxEnv( $global:TK )

# Change title to selected dbx
$var_cgTitle.Set_Content($dbks)

# Populate the combo drop downs
$var_GList.Items | ForEach-Object{
    $var_GroupOrigin.Items.Add($_.ToString())
}

$var_WList.Items | ForEach-Object{
    # List all workspaces except this one
    if ($_.ToString() -ne $dbks){
        $var_WsTarget.Items.Add($_.ToString())
    }
}


# Get selected group if any
$var_GroupOrigin.Add_SelectionChanged({

    $global:SEL_GRP = ($var_GroupOrigin.SelectedItem).ToString()
    Write-Host('Selected group: ' +  $global:SEL_GRP)
})
# Get selected workspace if any
$var_WsTarget.Add_SelectionChanged({

    $global:SEL_WS = ($var_WsTarget.SelectedItem).ToString()
    Write-Host('Selected workspace: ' +  $global:SEL_WS)
})



# COPY GROUP TO TARGET WORKSPACE ----------------------------------------------
$var_CopyGroup.Add_Click({

    if(not_set  $global:SEL_GRP){
        showErrMsg('Select a Group.')
        return;
    }
    if(not_set $global:SEL_WS){
        showErrMsg('Select a target Workspace.')
        return;
    }
    $msg = "Clone Group " + $global:SEL_GRP + " in workspace " + $global:SEL_WS + "?"
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    try{
        # Copy op - There is no copy/clone op per say. So,  need to first add a group with the same name, then add members one by one.

        # Get group & members origin
        $uList =  Get-DatabricksGroupMembers -BearerToken $global:TK -GroupName $global:SEL_GRP | 
                        Select-Object -ExpandProperty user_name | Sort-Object
        Write-Host ("Members: " + $uList)

        # Set group & members target
        $tok_target = $dbksTokens[$global:SEL_WS]
        set-DbxEnvAny $tok_target  $global:SEL_WS

        Write-Host ("Adding group " + $global:SEL_GRP + " to workspace " + $global:SEL_WS)
        #azure.databricks.cicd.tools\Add-DatabricksGroup -BearerToken $tok_target  -GroupName  $global:SEL_GRP
        Add-DatabricksGroup -BearerToken $tok_target -GroupName  $global:SEL_GRP
        $uList | ForEach-Object{
            Add-DatabricksMemberToGroup -BearerToken $tok_target -Member $_ -Parent $global:SEL_GRP
            Write-Host("Added member " + $_)
        }
        ShowMsg("Group cloned in chosen target workspace.")
    }
    catch [Exception]{
        Write-Debug $_
        showErrMsg  $_
        return;
     }
    
})






# All code before this  
$Null = $window_cg.ShowDialog()