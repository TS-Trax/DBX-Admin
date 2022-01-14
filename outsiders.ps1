# ==============================================================================================
# Databricks Admin GUI Tool - Outsiders (orphaned users) processing window
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================

Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms

$xamlFile4 = '.\files\Outsiders.xaml'

#create window
$inputXML4 = Get-Content $xamlFile4 -Raw -Force
$inputXML4 = $inputXML4 -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$xaml4 = $inputXML4

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml4)
try {
    $window4 = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'

$xaml4.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window4.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}
Get-Variable var_*

#----------------------------------------------------------------------------------------------
# IMAGES - source in XAML not working with Powershell
$var_dbxLogo.Source   = ".\files\dbks.png"

# Only allow minimizing the window, not resizing it
$window4.resizeMode = 'CanMinimize'


#---------------------------------------------------


# Global dynamic vars 
$TK = $dbksTokens[$dbks]
set-DbxEnv( $TK )

# Change title to selected dbx
$var_WksTitle.Set_Content($dbks)

printGlobals

# Listbox
[void] $var_NGList.Items.clear()
$global:noGrp | ForEach-Object{

    if( ! $var_NGList.Items.Contains($_)){
        $var_NGList.Items.Add($_)
    }
}

# Combobox
[void] $var_AllGrps.Items.clear()
$global:allGrps | ForEach-Object{

    if( ! $var_AllGrps.Items.Contains($_)){
        $var_AllGrps.Items.Add($_)
    }
}

# Buttons ----------------------------------------

$var_NGAdd.Add_Click( {
    
    $selUsr = $var_NGList.SelectedItem
    $selGrp = $var_AllGrps.SelectedItem
 
    if( [string]::IsNullOrEmpty($selUsr) ){
        $msg = "Select a user"
        showErrMsg ($msg)
        return;
    }
    if( [string]::IsNullOrEmpty($selGrp) ){
        $msg = "Select a Group"
        showErrMsg ($msg)
        return;
    }
    $msg = "Add user " + $selUsr + " to group " + $selGrp + " in " + $dbks + "?"
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    else{ # ADD USER ----------------------------------------------------------------
        Write-Host ("Adding user " + $selUsr + " to group " + $selGrp + " in  " + $dbks)
        try{
            Add-DatabricksGroupMember -UserName $selUsr -ParentGroupName $selGrp
            showMsg ("User " + $selUsr + " added to group " + $selGrp + " in  " + $dbks)
            $var_NGList.Items.Remove($selUsr)
            return;
        }
        catch [Exception]{
            Write-Debug $_
            showErrMsg  $_
            return;
         }
    }
})

# -----------------------------------------------------------------------------------

$var_NGRemove.Add_Click( {

    $users = $global:dbxUsers
    $selUsr = $var_NGList.SelectedItem
 
    if( [string]::IsNullOrEmpty($selUsr) ){
        $msg = "Select a user"
        showErrMsg ($msg)
        return;
    }
    $msg = "Remove user " + $selUsr + " in " + $dbks + "?"
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    else{ # REMOVE USER ------------------------------------------------------------------
        Write-Host ("Removing user " + $selUsr +  " with ID = " + $users[$selUsr] + " in  " + $dbks)
        try{
            Remove-DatabricksUser -BearerToken $TK -UserId $users[$selUsr]
            #showMsg ("User " + $selUsr + " removed from  " + $dbks)
            $var_NGList.Items.Remove($selUsr)
            return;
        }
        catch [Exception]{
            Write-Debug $_
            showErrMsg  $_
            return;
        }
    }
    
})
# -------------------------------------------------------------------------------------------



# All code before this  
$Null = $window4.ShowDialog()