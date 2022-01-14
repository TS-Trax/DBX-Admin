# ==============================================================================================
# Databricks Admin GUI Tool - Common functions & constructs
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================

# -------------------------------------
function showWarnMsg ($msg){
    Write-Warning $msg
   [System.Windows.Forms.MessageBox]::Show($msg, "WARNING", `
   [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
}

# -------------------------------------
function showErrMsg ($msg){
    Write-Warning $msg
   [System.Windows.Forms.MessageBox]::Show($msg, "ERROR", `
   [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}
# -------------------------------------
# Display info message, both on the comand line and via dialog box.
function showMsg ($msg){
    Write-Warning $msg
   [System.Windows.Forms.MessageBox]::Show($msg, "INFO", `
   [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# -------------------------------------
# Display OK/cancel confirmation message, both on the command line and via dialog box.
# Returns '1' for continue and '0' to cancel.
function showConfirmDialog ($msg){
    Write-Warning $msg
   $ret = [System.Windows.Forms.MessageBox]::Show($msg, "CONFIRMATION", `
          [System.Windows.Forms.MessageBoxButtons]::OKCancel, `
          [System.Windows.Forms.MessageBoxIcon]::Warning)

   switch ($ret){
        "OK"     { return 1; } 
        "Cancel" { return 0; } 
   }
}

# -------------------------------------
# Display yes/no confirmation message, both on the command line and via dialog box.
# Returns '1' for continue and '0' to cancel.
function showConfirmYesNoDialog ($msg){
    Write-Warning $msg
   $ret = [System.Windows.Forms.MessageBox]::Show($msg, "CONFIRMATION", `
          [System.Windows.Forms.MessageBoxButtons]::YesNo, `
          [System.Windows.Forms.MessageBoxIcon]::Warning)

   switch ($ret){
        "Yes" { return 1; } 
        "No"  { return 0; } 
   }
}

# -------------------------------------
function IsValidEmail { 
    param([string]$EmailAddress)
    #Write-Host ("Checking email validity for: " + $EmailAddress)
    try {
        $null = [mailaddress]$EmailAddress
        #Write-Host "Valid email"
        return $true
    }
    catch {
        Write-Warning ("Invalid email: " + $EmailAddress)
        return $false
    }
}

#-----------------------------------------------
function get_text($txtBox){
    return $txtBox.text.ToString().Trim()
}


function is_set( $thing ){
    return !( [string]::IsNullorWhiteSpace($thing) ) 
}
function not_set( $thing ){
    return  [string]::IsNullorWhiteSpace($thing)  
}

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