# ==============================================================================================
# Databricks Admin GUI Tool - Databricks WQorkspaces Window
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================

Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms

$xamlFile_ws = '.\files\Workspaces.xaml'

#create window
$inputXML_ws = Get-Content $xamlFile_ws -Raw -Force
$inputXML_ws = $inputXML_ws -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$xaml_ws = $inputXML_ws

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml_ws)
try {
    $window_ws = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'

$xaml_ws.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window_ws.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}
Get-Variable var_* | Out-Null

#----------------------------------------------------------------------------------------------
# IMAGES - source in XAML not working with Powershell
$var_dbxLogo.Source   = ".\files\dbks.png"

# Only allow minimizing the window, not resizing it
$window_ws.resizeMode = 'CanMinimize'

Import-Module .\common.ps1 -Force


# Dynamic vars 
$global:SEL_ITEM = $null
$global:TK = $dbksTokens[$dbks]
set-DbxEnv( $global:TK )

# Change title to selected dbx
$var_WsTitle.Set_Content($dbks)



#-------------------------------------
function reset_previous($emptyPath){

    $var_WsPath.Clear()
    If($emptyPath.length -eq 0){
        $prevPath = '/'
    }
    else{
        $prevPath = $emptyPath.Substring(0, $emptyPath.LastIndexOf('/') )
        If(not_set $prevPath){ # Only one slash in $emptyPath. e.g. /Repos
            $prevPath = '/'
        }
        #Write-Host $prevpath
        $var_WsPath.AddText($prevPath)
        $prev = azure.databricks.cicd.tools\Get-DatabricksWorkspaceFolder  -Path $prevPath
        $pathList = $prev.path | Sort-Object
        $pathList | ForEach-Object {
            if( ! $var_WsContents.Items.Contains($_)){
                [void] $var_WsContents.Items.Add($_) 
                #Write-Host $_
            }
        }
    }
}

#-------------------------------------
function reset_root(){

    if(not_set ( get_text ($var_WsPath) )){
        $var_WsPath.AddText('/')
    }
    $root = azure.databricks.cicd.tools\Get-DatabricksWorkspaceFolder  -Path /
    $pathList = $root.path  | Sort-Object
    $pathList | ForEach-Object {
        if( ! $var_WsContents.Items.Contains($_)){
            [void] $var_WsContents.Items.Add($_) 
            #Write-Host $_
        }
    }
}
# CALL
reset_root


#-------------------------------------
function show_contents(){

    $input = get_text $var_WsPath
    if(not_set $input){
        $msg = "No Path to work with!"
        showErrMsg ($msg)
        return 0;
    }
    #[void] Write-Host $input
    $var_WsContents.Items.Clear()
    try{
        $contents = (azure.databricks.cicd.tools\Get-DatabricksWorkspaceFolder  -Path $input).path | Sort-Object
        if($contents.Count -eq 0){
            $msg = "No contents to display! Will revert to parent folder."
            showErrMsg ($msg)
            #[void] Write-Host $input
            reset_previous $input
            return 0;
        }
        $contents | ForEach-Object{
            if( ! $var_WsContents.Items.Contains($_)){
                [void] $var_WsContents.Items.Add($_) 
            }
        }
    }
    catch [Exception]{
        Write-Debug $_
        showErrMsg  $_
        return 0;
    }
    return 1;
}

# Back to Parent folder --------------------------------------------
$var_ParentPath.Add_Click({

    $input = get_text $var_WsPath
    if($input -ne '/'){
        reset_previous $input
    }

})

# SHOW PATH CONTENTS AS USER TYPES ----------------------------------
$var_WsPath.Add_TextChanged({
    
})

# SHOW PATH CONTENTS ------------------------------------------------
$var_ShowWS.Add_Click({

    if(show_contents -eq 0){
        return;
    }
})



# CONTENT SELECTION ------------------------------------------------
$var_WsContents.Add_SelectionChanged({

    $sel = $var_WsContents.SelectedItem
    $global:SEL_ITEM   = $sel
    Write-Host $sel
    $var_WsPath.Clear()
    $var_WsPath.AddText($sel)
})




# EXPORT -----------------------------------------------------------
$var_ExportWs.Add_Click({

    $ExportPath =  $global:SEL_ITEM
    if(not_set $ExportPath){
        $msg = "No selection to work with!"
        showErrMsg ($msg)
        return;
    }
    # Export format
    $format = 'SOURCE' # Default
    if($var_ExportSource.IsChecked){
        $format = 'SOURCE'
    }
    elseif($var_ExportDBC.IsChecked){
        $format = 'DBC'
    }
    elseif($var_ExportHTML.IsChecked){
        $format = 'HTML'
    }
    elseif($var_ExportJupyter.IsChecked){
        $format = 'JUPYTER'
    }

    Write-Host $format

    $LocalOutputPath = '/DBX-Admin/Exports/'
    $msg = 'Will export ' + $ExportPath + ' in ' + $format + ' format to local directory ' + $LocalOutputPath + ' where this action is executed. Proceed?'
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    show_progress
    $Win.Title = "Exporting..."
    try{
        azure.databricks.cicd.tools\Export-DatabricksFolder -ExportPath $ExportPath  -LocalOutputPath $LocalOutputPath  -Format $format -Verbose
    }
    catch [Exception]{
        Write-Debug $_
        hide_progress
        showErrMsg  $_
        return;
    }
    hide_progress
    showMsg 'Export operation successful.'
})



# IMPORT -----------------------------------------------------------
$var_ImportWs.Add_Click({

    $msg = "Only DBC format is supported at this time. Imported content will be placed under an '/imported' subfolder. Proceed?"
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    $dbxPath =  $global:SEL_ITEM
    if(not_set $dbxPath){
        $msg = "No path was selected in the workspace, therefore the content will be imported at the root folder level."
        $msg += "`nIf this was not the intended behavior, go back and select a path first. Otherwise, proceed."
        if( -not (showConfirmDialog  $msg) ){
            return;
        }
    }
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.InitialDirectory = $InitialDirectory
    $OpenFileDialog.ShowDialog() | Out-Null
    if( not_set $OpenFileDialog.FileName){
        Write-Debug 'No file or folder was chosen. Returning..'
        return;
    }
    $import =  $OpenFileDialog.FileName
    <#
    $extension = $import.Substring($import.LastIndexOf('.') + 1).ToUpper()

     # Import format
     $format = 'SOURCE' # Default
     if($extension -in ("SCALA", "PY", "SQL", "R")){
         #Write-Host 'Format is SOURCE'
         $format = 'SOURCE'
     }
     elseif($extension -eq 'DBC'){
         $format = 'DBC'
     }
     elseif(extension -eq 'HTML'){
         $format = 'HTML'
     }
     elseif($extension -eq 'JPYNB'){
         $format = 'JUPYTER'
     }
     else{
         $msg = "Unsupported file extension '" + $extension + "'`nSupported file extensions are SCALA, PY, SQL, R, DBC, HTML, JPYNB "
        showErrMsg($msg)
        return;
     }
     #>
    $wsPath = '/imported/'
    if(is_set $dbxPath){
        $wsPath = $dbxPath + '/imported/' 
    }
    Write-Host ("Local path: " +  $import)
   # Write-Host ("Format: " +  $format)
    Write-Host ("Workspace path: " +  $wsPath)
    
    show_progress
    $Win.Title = "Importing..."
    try{
        DatabricksPS\Import-DatabricksWorkspaceItem  -Path $wsPath  -Format "DBC" -LocalPath $import  -Overwrite $false
    }
    catch [Exception]{
        Write-Debug $_
        hide_progress
        showErrMsg  $_
        return;
    }
    hide_progress
    showMsg 'Import operation successful.'

})




# REMOVE -------------------------------------------------------------
$var_RemoveWs.Add_Click({

    $RemovePath =  $global:SEL_ITEM

    # Check for SP and prevent deletion
    if( $Removepath.StartsWith("/Users/") ){
        $usr = $RemovePath.Substring(7)
        Write-Host $usr
        if( -not (IsValidEmail($usr)) ){
            $msg = "Not an email format. Most likely a Service Principal. If you MUST remove it, switch to manual mode."
            showErrMsg ($msg)
            return;
        }
    }
    $msg = 'Will remove ' + $RemovePath + ' and all its content. This operation cannot be undone. Proceed?'
    $msg += "`n`n Warning: This is a potentially long-running operation."
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    show_progress
    $Win.Title = "Removing..."
    try{
        # if -Recursive $false, will get {"error_code":"DIRECTORY_NOT_EMPTY","message":"Folder (/Users/tester@test.com) is not empty"}
        DatabricksPS\Remove-DatabricksWorkspaceItem -Path $RemovePath -Recursive $true 
        $var_WsContents.Items.remove($RemovePath)
    }
    catch [Exception]{
        Write-Debug $_
        hide_progress
        showErrMsg  $_
        return;
    }
    hide_progress
    showMsg 'Remove operation successful.'
})







# All code before this  
$Null = $window_ws.ShowDialog()