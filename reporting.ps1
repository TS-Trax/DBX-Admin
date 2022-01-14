# ==============================================================================================
# Databricks Admin GUI Tool - Reporting Window
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================

Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms

$xamlFile_R = '.\files\Report.xaml'

#create window
$inputXML_R = Get-Content $xamlFile_R -Raw -Force
$inputXML_R = $inputXML_R -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$xaml_R = $inputXML_R

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml_R)
try {
    $window_R = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'

$xaml_R.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window_R.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}
Get-Variable var_* | Out-Null

#----------------------------------------------------------------------------------------------
# IMAGES - source in XAML not working with Powershell
$var_dbxLogo.Source   = ".\files\dbks.png"
$var_reportingLogo.Source   = ".\files\reporting.png"

$window_R.resizeMode = 'CanMinimize'


#------------------------------------------------------------
$global:report = 'REPORT'

function createReport(){

    $tbl = $global:reportTable
    if($null -eq $tbl -or $tbl.Count -eq 0){
        ShowMsg("Report is empty. Run checks before generating the report.")
        return;
    }
    if($var_FWord.IsChecked){ # WORD format (default)
        $Word = New-Object -ComObject Word.Application
        $Word.Visible = $True
        $Document = $Word.Documents.Add()
        $Selection = $Word.Selection
        $Selection.Style = 'Title'
        $Selection.TypeText("DBX-Admin Report")
        $Selection.TypeParagraph()
        $Selection.Style = 'Subtitle'
        $Selection.TypeText("$(Get-Date)")
        $Selection.TypeParagraph()

        foreach($h in $tbl.Keys){
            $Selection.TypeParagraph()
            $Selection.Style = 'Heading 1'
            $Selection.TypeText($h)
            $Selection.TypeParagraph()
            $Selection.TypeParagraph()
            $Selection.Style = 'Normal'
            $Selection.TypeText($tbl.Item($h))
            $Selection.TypeParagraph()
        }
        $Report = 'DBX-Admin-Report.doc'
        $Document.SaveAs([ref]$Report,[ref]$SaveFormat::wdFormatDocument)
        showMsg($Report +" saved in Documents folder.")
        $word.Quit()
        $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$word)
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
        Remove-Variable word 
    }
    elseif ($var_FText.IsChecked){  # Text format
        $global:report += "- $(Get-Date)"
        foreach($h in $tbl.Keys){
            $global:report += "`n `n"
            $global:report += $h
            $global:report += "`n" + $tbl.Item($h)
            $global:report += "`n `n"
        }
        $Filename = "DBX-Admin-Report.txt"
        New-Item -Path . -Name $Filename -ItemType "file" -Value $global:report -Force
        showMsg($Filename + " saved in current directory.")
    }
}

# CHECK - Every result that was obtained by the user
$table = $global:reportTable
if($table.ContainsKey($global:ClusterCheck)){
    $var_RClusters.IsChecked = $True
}
if($table.ContainsKey($global:ClusterJobsErrors)){
    $var_RFailures.IsChecked = $True
}
if($table.ContainsKey($global:VMTypeCheck)){
    $var_RVMs.IsChecked = $True
}
if($table.ContainsKey($global:RuntimeCheck)){
    $var_RRuntime.IsChecked = $True
}

#----------------------------------------CREATE REPORT EVENT--------------------------------------------------

$var_CreateR.Add_Click({

    $msg = "Will save the results obtained on clusters running, cluster/job errors, VM types and runtime versions" 
    $msg += " used on all listed workspaces. Proceed?"
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    createReport 
})




# All code before this  
$Null = $window_R.ShowDialog()