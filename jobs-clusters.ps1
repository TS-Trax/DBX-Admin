# ==============================================================================================
# Databricks Admin GUI Tool - Cluster Monitoring Window
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================

Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms

$xamlFile2 = '.\files\Clusters.xaml'

#create window
$inputXML2 = Get-Content $xamlFile2 -Raw -Force
$inputXML2 = $inputXML2 -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$xaml2 = $inputXML2

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml2)
try {
    $window2 = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'

$xaml2.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window2.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}
Get-Variable var_* | Out-Null

#----------------------------------------------------------------------------------------------
# IMAGES - source in XAML not working with Powershell
$var_dbxLogo.Source   = ".\files\dbks.png"
$var_jobClick.Source   = ".\files\job.png"

# Only allow minimizing the window, not resizing it
$window2.resizeMode = 'CanMinimize'


# Dynamic vars 
$global:SEL_CLUSTER = $null
$global:TK = $dbksTokens[$dbks]
set-DbxEnv( $global:TK )

# Change title to selected dbx
$var_WksTitle.Set_Content($dbks)

$Running_color = 'red'

#----------------------------------------------------------------------------------------------

function is_set( $thing ){
    return !( [string]::IsNullorWhiteSpace($thing) ) 
}

function show_details ($cluster){
    #Write-Host('details')
    #Write-Host $cluster
    $var_ClusterDetails.Set_Header($cluster.cluster_name)
    $var_SparkVersion.Set_Content(". Spark Version: " + $cluster.spark_version)
    $var_DriverNode.Set_Content(". Driver Node: " + $cluster.driver_node_type_id)  
    $var_NodeType.Set_Content(". Node Type: " + $cluster.node_type_id) 
    $var_AutoTerm.Set_Content(". Auto-termination (min): " + $cluster.autotermination_minutes) 
    $var_State.Set_Content(". State: " + $cluster.state)
    enable-buttons ($cluster)
    $var_StateMsg.Set_Content(". State Message: " + $cluster.state_message)
    $var_Autoscale.Set_Content(". Autoscale: " + $cluster.autoscale)
    $var_TermReason.Set_Content(". Termination Reason: " + $cluster.termination_reason ) 
}

function reset_details (){
    #Write-Host('reset details')
    $var_ClusterDetails.Set_Header("Job / Cluster Details")
    $var_SparkVersion.Set_Content("Spark Version")
    $var_DriverNode.Set_Content("Driver Node")  
    $var_NodeType.Set_Content("Node Type") 
    $var_AutoTerm.Set_Content("Auto-termination (min)") 
    $var_State.Set_Content("State")
    $var_StateMsg.Set_Content("State Message")
    $var_Autoscale.Set_Content("Autoscale")
    $var_TermReason.Set_Content("Termination Reason") 
}
  
# Check cluster state to enable/disable buttons
function enable-buttons ($cluster){
    #Write-Host ("Enable buttons for state " + $cluster.State)
    switch($cluster.State){
    'TERMINATED'             { $var_CStart.IsEnabled = $True;  $var_CRestart.IsEnabled = $False;  $var_CStop.IsEnabled = $False; $var_CDelete.IsEnabled = $True } 
    'RUNNING'                { $var_CStart.IsEnabled = $False; $var_CRestart.IsEnabled = $True;   $var_CStop.IsEnabled = $True;  $var_CDelete.IsEnabled = $True }
    'DRIVER_NOT_RESPONDING'  { $var_CStart.IsEnabled = $False; $var_CRestart.IsEnabled = $True;   $var_CStop.IsEnabled = $True;  $var_CDelete.IsEnabled = $True }
    'RESIZING'               { $var_CStart.IsEnabled = $False; $var_CRestart.IsEnabled = $True;   $var_CStop.IsEnabled = $True;  $var_CDelete.IsEnabled = $True }
    'STARTING'               { $var_CStart.IsEnabled = $False; $var_CRestart.IsEnabled = $True;   $var_CStop.IsEnabled = $True;  $var_CDelete.IsEnabled = $True }
    'RESTARTING'             { $var_CStart.IsEnabled = $False; $var_CRestart.IsEnabled = $False;  $var_CStop.IsEnabled = $True;  $var_CDelete.IsEnabled = $True }
    'TERMINATING'            { $var_CStart.IsEnabled = $False; $var_CRestart.IsEnabled = $False;  $var_CStop.IsEnabled = $False; $var_CDelete.IsEnabled = $True }
    'PENDING'                { $var_CStart.IsEnabled = $False; $var_CRestart.IsEnabled = $False;  $var_CStop.IsEnabled = $True;  $var_CDelete.IsEnabled = $True }
     default                 { $var_CStart.IsEnabled = $False; $var_CRestart.IsEnabled = $False;  $var_CStop.IsEnabled = $False; $var_CDelete.IsEnabled = $True }
    }
}

function is_tempState($cluster){
    return  ($cluster.State -eq 'PENDING') -or
             ($cluster.State -eq 'STARTING') -or 
             ($cluster.State -eq 'RESTARTING') -or 
             ($cluster.State -eq 'TERMINATING') -or
             ($cluster.State -eq 'RESIZING')
}

function get-cluster ($name){
    $clist =  Get-DatabricksClusters -BearerToken  $global:TK
    $clist | ForEach-Object { 
        if($_.cluster_name -eq $name){
           return ($_)
        }
    }
}

function find-item($name){
    $var_ClusterList.Items | ForEach-Object{
        if($_.content -eq $name){
            return $_
        }
    }
}

function refreshState( $cluster){
    if( -not $cluster){
        return;
    }
    Write-Host("Cluster refreshed: " + $cluster.cluster_name)

    # Give it time to change its state following the cluster action
    start-sleep -Milliseconds 1000

    try{ $cluster = Get-DatabricksCluster -ClusterID $cluster.cluster_id }
    catch{ <# Ignore deleted cluster #> 
        Write-Host 'Cluster was deleted. Skipping.'
        return;
    }

    $var_State.Set_Content(". State: " + $cluster.state);
    $var_StateMsg.Set_Content(". State Message: " + $cluster.state_message);
    enable-buttons ($cluster)

    # Dynamic state refresh
    $window2.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::Background, [action]{ 
            Write-Host("JOB started")
            while( is_tempState($cluster) ){
                Write-Host("TEMP state: " + $cluster.state + ". Retrying in 3 seconds")
                start-sleep -Milliseconds 3000
                $cluster = Get-DatabricksCluster -ClusterID $cluster.cluster_id
                $var_State.Set_Content(". State: " + $cluster.state);
                $var_StateMsg.Set_Content(". State Message: " + $cluster.state_message);
                enable-buttons ($cluster)
            }
            Write-Host("Reached stable state: " + $cluster.state)
            $itm = find-item($cluster.cluster_name)
            if($cluster.state -eq "RUNNING"){
                $itm.Foreground = $Running_color
            }
            else{
                $itm.Foreground = 'black'
            }
    })
}



function cluster_action($action){
    $clu = $global:SEL_CLUSTER 
    $tk = $global:TK 
    if($null -eq $clu){
        $msg = "No cluster selected!"
        showErrMsg $msg
        return;
    }
    $msg = $action + ' cluster ' + $clu.cluster_name + "?"
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    else{
        try{
            $msg = ''
            $name = $clu.cluster_name 
            switch($action){
                'START'   { Start-DatabricksCluster -ClusterName $name -BearerToken $tk ; $msg = "Started" }
                'RESTART' { Restart-DatabricksCluster -ClusterName $name -BearerToken $tk ; $msg = "Restarted" }
                'STOP'    { Stop-DatabricksCluster -ClusterName $name -BearerToken $tk ; $msg = "Stopped"  }
                'DELETE'  { Remove-DatabricksCluster -ClusterName $name -BearerToken $tk ; $msg = "Removed"; 
                            $itm = find-item($name)
                            $var_ClusterList.Items.Remove( $itm )
                            Write-Host("Removed cluster " + $name )
                          }
            }
            
            refreshState($clu)
            showMsg ( $msg + " Cluster " + $name )
            return;
        }
        catch [Exception]{
            Write-Debug $_
            showErrMsg  $_
            return;
        }
    }    
}



# CLUSTERS --------------------------------------------------------------------------------------------------

function refresh_list(){
    $clist =  Get-DatabricksClusters -BearerToken  $global:TK 

    $runningList = @()
    $clist | ForEach-Object { 
        if($_.state -eq 'RUNNING'){
            #Write-Host ("Cluster " + $_.cluster_name + " is running")
            $runningList += $_.cluster_name
        }
    }
    
    $nameList = $clist  | Select-Object -ExpandProperty cluster_name -ErrorAction SilentlyContinue   | Sort-Object
    
    $nameList | ForEach-Object { 
        $itm = new-object System.Windows.Controls.ListboxItem
        $itm.Content = $_
        if ($_ -in $runningList){
            $itm.Foreground = $Running_color
        }
        $var_ClusterList.Items.Add($itm)
        
        # Add to combo boxes too
        $var_CopyFrom.Items.Add($_)
        $var_CopyTo.Items.Add($_)
    }    
}
# Call
refresh_list

$var_ClusterList.Add_SelectionChanged({

    $sel = $var_ClusterList.SelectedItem.Content
    Write-Host $sel
    # Get the cluster obj from the selected name
    $cluster = get-cluster($sel)
    $global:SEL_CLUSTER = $cluster

    # Print cluster obj details
    show_details($cluster)

    # Set selection label to selected name
    $var_CSelection.Set_Content($sel)

    #Get-DatabricksPermissions -ObjectType "CLUSTERS" -ObjectID $cluster.cluster_id
    #Get-DatabricksPermissionLevels  -DatabricksObjectType "cluster" -DatabricksObjectId $cluster.cluster_id
})



# CONTROL BUTTONs ---------------------------------------------------------------------------------------------------------------------------------------------

# START
$var_CStart.Add_Click({

    cluster_action('START')    
})

# RESTART
$var_CRestart.Add_Click({

    cluster_action('RESTART')  
})

# STOP
$var_CStop.Add_Click({

    cluster_action('STOP')   
})

# DELETE
$var_CDelete.Add_Click({

    cluster_action('DELETE')  
})

# CLUSTER LIBS - show in PS GridView
$var_CSlibs.Add_Click({

    $clu = $global:SEL_CLUSTER 
    if( $null -eq $clu ){
        $msg = "No cluster selected!"
        showErrMsg $msg
        return;
    }
    $libs =  Get-DatabricksLibraries  -BearerToken $global:TK   -ClusterID $clu.cluster_id
    $libTable = @{}
    foreach($lib in $libs){
        if( is_set $lib.library.whl) {
            $libTable.add($lib.library.whl, 'Wheel')
        }
        elseif( is_set $lib.library.pypi ){
            $libTable.add($lib.library.pypi.package, 'PyPi')
        }
        elseif( is_set $lib.library.maven ){
            $libTable.add($lib.library.maven, 'Maven')
        }        
    } # end loop
    if($libTable.Count -eq 0){
        $msg = "No libraries to display. `nTry another selection."
        showErrMsg $msg
        return;
    }
    $title = $dbks + ' / ' + $clu.cluster_name + " Libraries" 
    $libTable.GetEnumerator() | Select-Object @{l='Name';e={$_.Key}},@{l='Type';e={$_.Value}} |  Out-GridView -Title $title
})




#---------JOBS - show in PS GridView ------------------------------------------------------------------------------------

$var_jobPin.Add_Click({

    $jobs =  (DatabricksPS\Get-DatabricksJob) 
    If($jobs -eq $null){
        showErrMsg ("No jobs found in this workspace.")
        return;
    }
    show_progress
    $Win.Title = "Getting Jobs..."
    #--------------------------------------
    $jtable = @{}
    $jobs | ForEach-Object{
        $jtable.add($_.job_id, $_.settings.name)
    }
    $nl = [System.Environment]::NewLine
    $outputTable = @{}
    foreach( $jb in $jtable.GetEnumerator() ){
        $run = DatabricksPS\Get-DatabricksJobRun -JobID $jb.Name  -Limit 1  # only latest run 

        if($run.run_id -and $jb.Value -ne 'DLTpipe'){ # exclude existing Delta Live Table in Dev

           try{ 
               $output =  DatabricksPS\Get-DatabricksJobRunOutput -JobRunID $run.run_id 
            }
           catch{ # Retrieving the output of runs with multiple tasks (as in the new Dbx task orchestrator) is not supported.
                Write-Host 'Skipping multiple tasks run'
                continue;
             }
            $lifestate = $output.metadata.state.life_cycle_state
            $state = $output.metadata.state.result_state
            $message = $output.metadata.state.state_message
            $state_str = ' State: ' + $lifestate 
            if(is_set $state){
                $state_str += ($nl + ' Result: ' + $state)
            }
            if(is_set $message){
                $state_str +=  ($nl + ' Message: ' + $message)
            }
            if(! $outputTable.ContainsKey($jb.Value) ){
                $outputTable.add($jb.Value, $state_str )
            }
        } 
    }
    #--------------------------------------
    hide_progress

    $title = $dbks + " JOBS" 
    $outputTable.GetEnumerator() | Select-Object @{l='Name';e={$_.Key}},@{l='Details';e={$_.Value}} |  Out-GridView -Title $title

})




#---------COPY CLUSTER LIBS------------------------------------------------------------------------------------

$var_CopyLibs.Add_Click({

    if( not_set($var_CopyFrom.SelectedItem) ){
        $msg = "No Source cluster selected!"
        showErrMsg ($msg)
        return;
    }
    if( not_set($var_CopyTo.SelectedItem) ){
        $msg = "No Target cluster selected!"
        showErrMsg ($msg)
        return;
    }
    $srcClu = $var_CopyFrom.SelectedItem
    $destClu = $var_CopyTo.SelectedItem

    Write-Host ('Source cluster: ' + $srcClu)
    Write-Host ('Target cluster: ' + $destClu)

    if( $srcClu -eq $destClu){
        $msg = "Same cluster selected for source and target!"
        showErrMsg ($msg)
        return;
    }
    $msg = "Copy libraries from cluster " + $srcClu + " to cluster " + $destClu + "?" 
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    
    # get the clusters with those names
    $cluster_src = get-cluster $srcClu
    $cluster_target = get-cluster $destClu

    if($cluster_target.State -ne 'RUNNING'){
        $msg = "Destination cluster must be in RUNNING state! Start the cluster using the control button below."
        showErrMsg ($msg)
        return;
    }
    # Proceed with Libs copy
    $libs =  azure.databricks.cicd.tools\Get-DatabricksLibraries  -BearerToken $global:TK   -ClusterID $cluster_src.cluster_id    
    Write-Host ('Libs to copy: ' + $libs)

    # Fails half-way if trying to add as a bulk. Try adding one after another to skip errors & continue
    show_progress
    $Win.Title = "Copying libraries..."
    foreach($lib in $libs.library) {
        $arg = @()
        $info = ("Adding library " + $lib)
        Write-Host $info
        $Win.Title = $info
        $arg += $lib
        try { 
            DatabricksPS\Add-DatabricksClusterLibraries -ClusterID $cluster_target.cluster_id -Libraries $arg 
        }
        catch { Write-Warning $_.Exception }
        $arg.clear()
    }
    $Win.Title = "Copy action completed."
    hide_progress


})





# All code before this  
$Null = $window2.ShowDialog()

