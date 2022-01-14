# ==============================================================================================
# Databricks Admin GUI Tool - Splash screen
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================
Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms

$xamlFile_splash= '.\files\Screen.xaml'

#create window
$inputXML_splash = Get-Content $xamlFile_splash -Raw -Force
$inputXML_splash = $inputXML_splash-replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$xaml_splash = $inputXML_splash

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml_splash)
try {
    $window_splash= [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}
# Create variables based on form control names.
# Variable will be named as 'var_<control name>'

$xaml_splash.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window_splash.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}
Get-Variable var_*

$var_adminLogo.Source = ".\files\admin.png"

<#
$window_splash.Show()
start-sleep -Milliseconds 10000
$window_splash.Hide()
#>