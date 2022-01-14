# ==============================================================================================
# Databricks Admin GUI Tool - Key Vault Configuration Window
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================

Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms

$xamlFile3 = '.\files\Security.xaml'

#create window
$inputXML3 = Get-Content $xamlFile3 -Raw -Force
$inputXML3 = $inputXML3 -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$xaml3 = $inputXML3

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml3)
try {
    $window3 = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'

$xaml3.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window3.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}
Get-Variable var_* | Out-Null

#----------------------------------------------------------------------------------------------
# IMAGES - source in XAML not working with Powershell
$var_kvLogo.Source   = ".\files\kv.png" 
$window3.resizeMode = 'CanMinimize'

#$vaultName = 'kv-wdp-dev'
Write-Host ("Saved from dbx-admin-config: " + "'" + $global:KV  + "'" + ", '" + $global:FILTER + "'" )

Import-Module Az.KeyVault


# UI ------------------------------------------------------------------------------
$var_KVaults.Items.Add( $global:KV  )
$var_KVaults.SelectedItem = $global:KV 

show_progress #-----
$Win.Title = "Retrieving Key Vault configuration..."

try{
    $secretList = (Get-AzKeyVaultSecret -VaultName $global:KV  | 
                Select-Object Name  -ErrorAction SilentlyContinue | 
                    Where-Object Name  -Like $global:FILTER  | Sort-Object).Name
}   
catch [Exception]{
    Write-Warning $_
    #showErrMsg  $_
}
Write-Host ("Secrets: " + $secretList)

$secretList | ForEach-Object{
    if( ! $var_Secrets.Items.Contains($_)){
        [void] $var_Secrets.Items.Add($_) 
        #Write-Host $_
    }
}

hide_progress #-----


# All code before this  
$Null = $window3.ShowDialog()