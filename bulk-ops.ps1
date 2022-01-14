# ==============================================================================================
# Databricks Admin GUI Tool - Bulk operations Window
# https://github.com/TS-Trax/DBX-Admin
#================================================================================================

Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms

$xamlFile_bk = '.\files\Bulk.xaml'

#create window
$inputXML_bk = Get-Content $xamlFile_bk -Raw -Force
$inputXML_bk = $inputXML_bk -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[XML]$xaml_bk = $inputXML_bk

#Read XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml_bk)
try {
    $window_bk = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning $_.Exception
    throw
}

# Create variables based on form control names.
# Variable will be named as 'var_<control name>'

$xaml_bk.SelectNodes("//*[@Name]") | ForEach-Object {
    #"trying item $($_.Name)"
    try {
        Set-Variable -Name "var_$($_.Name)" -Value $window_bk.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}
Get-Variable var_* | Out-Null

#----------------------------------------------------------------------------------------------
# IMAGES - source in XAML not working with Powershell
$var_dbxLogo.Source   = ".\files\dbks.png"

# Only allow minimizing the window, not resizing it
$window_bk.resizeMode = 'CanMinimize'


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

#-----------------------------------------------
function set_filters( $search1, $search2){
    if( is_set($search1) ){
        if( is_set($search2) ){
            return ( "(?=.*" + $search1 + ')|(?=.*' + $search2 + ')')
        }
        else{
            return  ( "(?=.*" + $search1 + ')')
        }
    }
    else{
        if( is_set($search2) ){
            return $( "(?=.*" + $search2 + ')')
        }
        else{
            return ''
        }
    }
}

# Fuzzy Match module: https://github.com/gravejester/Communary.PASM
#Install-Module Communary.PASM -Scope CurrentUser -force
Import-Module Communary.PASM 

$global:matchCount = 0
$global:matchList = @()

#-----------------------------------------------
function fuzzy_match_group($usr, $grp, $action){

    Write-Host("Fuzzy matching group "+ $grp + " to existing ones in workspaces")
    $global:matchCount = 0
    $matchedGroups = @()

    $global:results | ForEach-Object{
        $tok = $dbksTokens[$_.Name] 
        set-DbxEnvAny $tok $_.Name

        $gList = get-DbxGroups($_.Name)
        Write-Host("Group List for  "+ $_.Name + ": `n" + $gList)

        $match = $gList | Select-ApproximateString $grp  

        if( $null -eq $match ){
            Write-Host ("- NO matches in " + $_.Name + ". Skipping...")
        }
        else{
            Write-Host ("- Fuzzy match result(s) for " + $grp + ": `n "  + $match)
            $global:matchCount += 1 
            $matchedGroups += $match
             foreach ($mg in $match) {
                    Write-Host ( "- Will use: "  + $mg) 
                    if($action -eq 'ADD'){
                        try{
                            Add-DatabricksUser -BearerToken $tok -Username $usr 
                            # Use this method to add to Group
                            DatabricksPS\Add-DatabricksGroupMember -UserName $usr -ParentGroupName $mg
                            Write-Host ("User " + $usr + " added to group " + $mg+ " in  " + $_.Name)
                        }
                        catch [Exception]{
                            Write-Host $_
                        }
                    }
                    elseif($action -eq 'REMOVE'){
                        try{
                            DatabricksPS\Remove-DatabricksGroupMember -UserName $usr -ParentGroupName  $mg
                            Write-Host ("User " + $usr + " removed from group " + $mg+ " in  " + $_.Name)
                        }
                        catch [Exception]{
                            Write-Host $_
                        }
                    }
                }
        }
    }
    $global:matchList = $matchedGroups
}


#------------------------------------------------------------
$global:backupCount = 0
function createGroupBackup ($token, $groupName){

    $uList =  Get-DatabricksGroupMembers -BearerToken $token -GroupName $groupName | 
                    Select-Object -ExpandProperty user_name | Sort-Object
   
    if( $uList.Count() -eq 0 ){
        return;
    }
    # Save the backup with greatest number of members
    if($uList.Count() -gt $global:backupCount ){
        $global:backupCount = $uList.Count()
        $outList = @()
        foreach($u in $uList) {
            $u += "`n"
            $outList += $u
        }
        $outList | Out-File -filepath ("./backups/" + $groupName + ".txt")
    }   
}

#------------------------------------------------------------
function print_list( $list, $state ){
    
    if($list.Count -eq 0){
        return;
    }
    $nl = [System.Environment]::NewLine
    $count = 0
    $list | ForEach-Object {
        if($count -eq 0){
             $var_ResultsClustersB.AppendText($state + ': ' + $nl)
             #Write-Host($state + ': ')
             $count = $count +1
        }
        $var_ResultsClustersB.AppendText($_  + $nl)
        #Write-Host ($_)
    }
    $var_ResultsClustersB.AppendText($nl)
    #Write-Host
}

#------------------------------------------------------------
function print_clusters($context, $csList){
    # DEBUG
    if( $true ){
        Write-Host '______________________________'
        Write-Host $context
        $csList  | ForEach-Object{
            Write-Host $_.cluster_name
        }
        Write-Host '______________________________'
    }
}
#------------------------------------------------------------
function print_jobs($context, $jbList){
    # DEBUG
    if( $true ){
        Write-Host '______________________________'
        Write-Host $context
        $jbList  | ForEach-Object{
            Write-Host $_.name
        }
        Write-Host '______________________________'
    }
}


# ------------------------------------------------
$global:reportTable  = @{}

$global:ClusterCheck = 'Cluster Check'
$global:ClusterJobsErrors = 'Clusters/Jobs Errors'
$global:VMTypeCheck = 'VM Type Check'
$global:RuntimeCheck = 'Runtime Version Check'

function add_to_report($title, $txtBox){
    $addtxt =  get_text($txtBox)
    $global:reportTable.Add($title, $addtxt)
}


#----------------------------------------------COMBO BOX---------------------------------------------------

$var_CurrentGroupB.Add_SelectionChanged({

    $selgroup = ($var_CurrentGroupB.SelectedItem.Content).ToString()
    if($selgroup -eq 'Custom Pattern'){
        $var_CustomPatternB.visibility = 'visible'
    }
    else{
        $var_CustomPatternB.visibility = 'hidden'
    }
})

#-----------------------------------------------BUTTONS--------------------------------------------------
$global:cacheList = @() # CACHE
$global:results = @()

$var_SearchWG.Add_Click( {

    show_progress
    $Win.Title = "Searching..."
    [void] $var_SearchResultsB.Items.clear()

    $Win.Title = "Searching Subscriptions..."
    $sub = Get-AzSubscription
    if( $global:cacheList.Count -eq 0){
        $initList = @()
        foreach($s in $sub){
            Get-AzSubscription -SubscriptionName $s.Name | Set-AzContext
            $initList += get-AllDBKS
            <#
            $initList | ForEach-Object{
                $tok = $dbksTokens[$_.Name] 
                set-DbxEnvAny $tok $_.Name
            }
            #>
        }
        $global:cacheList = $initList
    }
    else{
        Write-Host 'Accessing CACHE...'
    }

    $Win.Title = "Filtering..."
    $search1 = get_text($var_SearchWGText1)
    $search2 = get_text($var_SearchWGText2)
    $search_filter = set_filters $search1 $search2

    $nosearch1 = get_text($var_NoSearchWGText1)
    $nosearch2 = get_text($var_NoSearchWGText2)
    $noSearch_filter = set_filters $nosearch1 $nosearch2

    Write-Host("Search Include filter: " + $search_filter)
    Write-Host("Search Exclude filter: " + $noSearch_filter)
  
    $foundList0 = $global:cacheList  |  Where-Object Name -match  $search_filter 
    if( is_set($noSearch_filter) ){
        $foundList = $foundList0 |  Where-Object Name -notmatch  $noSearch_filter
    }
    else{
        $foundList =   $foundList0 
    }
 
    if($foundList.Count -eq 0){
        $msg = "No Results. Try a different search pattern."
        showErrMsg ($msg)
        hide_progress
        return;
    }
    
    $global:results = $foundList
    $foundList | ForEach-Object {
        if( ! $var_SearchResultsB.Items.Contains($_.Name)){
            [void] $var_SearchResultsB.Items.Add($_.Name) 
            Write-Host $_.Name
        }
    }
    hide_progress

    # Report generation
    $global:report += 'WORKSPACES: ' 
    $global:results | ForEach-Object{
        $global:report += "`n"
        $global:report += $_.Name
    }
    $global:report += "`n`n"
})

#------------------------------------------------ ADD/REMOVE USER ---------------------------------------------------------------------------

# ADD USER TO ALL LISTED WORKSPACES
$var_AddB.Add_Click( {

    $usr =  get_text($var_CurrentUserB)
    if( not_set($usr) ){
        $msg = "No User to Add!"
        showErrMsg ($msg)
        return;
    }
    if( -not (IsValidEmail($usr)) ){
        $msg = "Enter correct email format"
        showErrMsg ($msg)
        return;
    }
    if( not_set( $var_CurrentGroupB.SelectedItem) ){
        $msg = "No Group Pattern selected!"
        showErrMsg ($msg)
        return;
    }
    if( $var_SearchResultsB.Items.Count -eq 0){
        $msg = "No Workspace to process!"
        showErrMsg ($msg)
        return;
    }    

    $group = ($var_CurrentGroupB.SelectedItem.Content).ToString()
    if($group -eq 'Custom Pattern'){
        $group = get_text($var_CustomPatternB)
        if( not_set($group) ){
            showErrMsg('Custom Pattern is empty!')
            return;
        }
    }
    show_progress
    $Win.Title = "Adding..."
    #
    fuzzy_match_group $usr $group 'ADD'
    #
    hide_progress
    $msg = "Executed ADD '" + $usr + "' to all groups that fuzzy-matched '"+ $group + "' (Best Effort Operation - Number of matches = " + $global:matchCount + ")."
    $msg += "`n`nMatched with existing group(s): " + $global:matchList 
    showMsg($msg)

})

#----------------------------------------------------------------------

# REMOVE USER FROM GROUP IN ALL LISTED WORKSPACES
$var_RemoveB.Add_Click( {

    $usr =  get_text($var_CurrentUserB)
    if( not_set($usr) ){
        $msg = "No User to Remove!"
        showErrMsg ($msg)
        return;
    }
    if( -not (IsValidEmail($usr)) ){
        $msg = "Enter correct email format"
        showErrMsg ($msg)
        return;
    }
    if( not_set($var_CurrentGroupB.SelectedItem) ){
        $msg = "No Group Pattern selected!"
        showErrMsg ($msg)
        return;
    }
    if( $var_SearchResultsB.Items.Count -eq 0){
        $msg = "No Workspace to process!"
        showErrMsg ($msg)
        return;
    }    

    $group = ($var_CurrentGroupB.SelectedItem.Content).ToString()
    if($group -eq 'Custom Pattern'){
        $group = get_text($var_CustomPatternB)
        if( not_set($group) ){
            showErrMsg('Custom Pattern is empty!')
            return;
        }
    }
    # It is a remove op, seek confirmation
    $msg = "Remove user from groups matching the selected group pattern?"
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    show_progress
    $Win.Title = "Removing user..."
    #
    fuzzy_match_group $usr $group 'REMOVE'
    #
    hide_progress
    $msg = "Executed REMOVE '" + $usr + "' from all groups that fuzzy-matched '"+ $group 
    $msg += "' (Best Effort Operation - Number of matches = " + $global:matchCount + ")."
    $msg += " `n`nUser has been removed from those groups."
    $msg += "To remove the user from the workspaces, use the 'Outsiders' view (per workspace) or the 'Purge' action (for all listed workspaces)."
    $msg += "`n`nMatched with existing group(s): " + $global:matchList 
    showMsg($msg)

})




#----------------------------------------------------------------------

# REMOVE USER FROM ALL LISTED WORKSPACES (PURGE)
$var_PurgeB.Add_Click({

    $usr =  get_text($var_PurgeUserB)
    if( not_set($usr) ){
        $msg = "No User to Remove!"
        showErrMsg ($msg)
        return;
    }
    if( -not (IsValidEmail($usr)) ){
        $msg = "Enter correct email format"
        showErrMsg ($msg)
        return;
    }
    if( $var_SearchResultsB.Items.Count -eq 0){
        $msg = "No Workspace to process!"
        showErrMsg ($msg)
        return;
    } 
     # It is a remove op, seek confirmation  
    $msg = "Remove user from all listed worspaces?"
    if( -not (showConfirmDialog  $msg) ){
        return;
    }
    show_progress
    $Win.Title = "Removing user..."
    #
    $global:results | ForEach-Object{

        $tok = $dbksTokens[$_.Name] 
        set-DbxEnvAny $tok $_.Name
        
        $Win.Title = ("Processing " + $_.Name + "...")
        try{
            $userNameId = Get-DatabricksSCIMUser | Select-Object userName, id | Where-Object userName  -Like $usr

            Write-Host ("Found entry " + $userNameId + " and ID = " + $userNameId.id)
            Remove-DatabricksSCIMUser -UserID $userNameId.id
            $Win.Title = ("Removed user in "  + $_.Name + ".")
        }
        catch [Exception]{
            Write-Debug $_
            #showErrMsg  $_
            hide_progress
            return;
         }
    }  
    #
    hide_progress
    showMsg 'User removed from all listed workspaces'

})



#------------------------------------------------ ADD/REMOVE GROUP ---------------------------------------------------------------------------

# ADD GROUP TO ALL LISTED WORKSPACES
$var_AddBG.Add_Click( {

    $grp =  get_text($var_CurrentGroupBG)
    if( not_set($grp) ){
        $msg = "No Group to Add!"
        showErrMsg ($msg)
        return;
    }
    if( $var_SearchResultsB.Items.Count -eq 0){
        $msg = "No Workspace to process!"
        showErrMsg ($msg)
        return;
    }  
    if($global:ADDLIST.Count -eq 0){
        $msg = "No members were loaded for this new Group. Proceed anyway?"
        if( -not (showConfirmDialog  $msg) ){
                return;
        }
    }
    show_progress
    $Win.Title = "Processing..."

    ## START LOOP ---------------------------------------------
    $global:results | ForEach-Object{

        $tok = $dbksTokens[$_.Name] 
        set-DbxEnvAny $tok $_.Name

        # Get existing groups
        $gList = get-DbxGroups($_.Name)
        Write-Host("Group List for  "+ $_.Name + ": `n" + $gList)

        # Fuzzy match
        $match = $gList | Select-ApproximateString  $grp

        $grpAdd = $null #
        $createNew = $true #

        if($null -ne $match){
            if($match -eq $grp){ # Group already exists in this workspace - case-insensitive
                $msg = "The group: '" + $grp + "' already exist in '" + $_.Name + "'. Will add to existing group. Proceed?"
                if( showConfirmYesNoDialog $msg){
                    $Win.Title = "Adding to existing group " + $match + " in workspace " + $_.Name
                    $grpAdd = $match #
                    $createNew = $false #
                }
                else{ # Do nothing
                    $createNew = $false #
                    $grpAdd = $null #
                }
            }
            else{ # A similar group already exists in this workspace
                $msg = "A similar group: '" + $match + "' to group '" + $grp + "' already exist in '" + $_.Name + "'. Use existing group instead?"
                if( showConfirmYesNoDialog $msg){
                    $Win.Title = "Adding to existing group " + $match + " in workspace " + $_.Name
                    $grpAdd = $match #
                    $createNew = $false #
                }
                else{
                    $createNew = $true #
                    $grpAdd = $grp #
                }
            }
        }  
        else{ # Found no match in this workspace
            $createNew = $true #
            $grpAdd = $grp #
        }

        # Whether to create a new group for this workspace
        if($grpAdd -and $createNew){
            $Win.Title = "Adding new group " + $grpAdd + " to workspace " + $_.Name
            $grpAdd = $grp  #
            try{
                Add-DatabricksGroup -BearerToken $token -GroupName $grpAdd
            }
            catch [Exception]{
                Write-Debug $_
            }
        }
        # Add members if any
        if($global:ADDLIST.Count -gt 0){
            foreach ($u in $global:ADDLIST) {
                $Win.Title = "Adding member "+ $u + " to group " + $grpAdd 
                try{
                    Add-DatabricksUser -BearerToken $tok -Username $u
                    Add-DatabricksGroupMember -UserName $u -ParentGroupName $grpAdd
                }
                catch [Exception]{
                    Write-Debug $_
                }
            }
        }
    
    } 
    ## END LOOP ---------------------------------------------

    hide_progress
    showMsg("Processed group '" + $grp + "' in all listed workspaces.")
})



$global:ADDLIST = @()

# TO ADD GROUP WITH MEMBERS, LOAD FROM FILE
$var_LoadUsersBG.Add_Click({

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.InitialDirectory = $InitialDirectory
    #$OpenFileDialog.filter = "CSV (*.csv) | *.csv"
    $OpenFileDialog.ShowDialog() | Out-Null
    if( not_set $OpenFileDialog.FileName){
        Write-Debug 'No file was chosen. Returning..'
        return;
    }
    Write-Host  $OpenFileDialog.FileName
    $ulist = Get-Content -Path  $OpenFileDialog.FileName
    Write-Host($ulist)
    if($ulist.Count -eq 0){
        showErrMsg 'File is empty!'
    }
    else{
        # Make a pretty-print version just for display
        $counter = 0
        $displayUsers = $ulist | ForEach-Object {
           ($counter += 1).ToString() + '. ' + $_ + "`n"
        }
        if( -not (showConfirmDialog ("Load these users? `n`n " + $displayUsers)) ){
            return;
        }
        $global:ADDLIST = $ulist
        $var_LoadFileLabelBG.Set_Content('LOADED ' + $OpenFileDialog.FileName)
        $var_LoadFileLabelBG.Foreground = 'darkblue'
        #$var_LoadFileLabelBG.FontWeight = "Bold"
    }
})



# REMOVE GROUP FROM ALL LISTED WORKSPACES - DISABLED (NOT WORKING)
$var_RemoveBG.Add_Click( {

    $grp =  get_text($var_CurrentGroupBG)
    if( not_set($grp) ){
        $msg = "No Group to Remove!"
        showErrMsg ($msg)
        return;
    }
    if( $var_SearchResultsB.Items.Count -eq 0){
        $msg = "No Workspace to process!"
        showErrMsg ($msg)
        return;
    }  
    $msg = "Remove group '" + $grp + "' with all its members from ALL workspaces listed above?" 
    $msg += "`n `n As a restore option, a unique backup file will be created from the group with the most members."
    if( -not (showConfirmDialog  $msg) ){
        return;
    }

    $global:results | ForEach-Object{
        
        $tok = $dbksTokens[$_.Name] 
        set-DbxEnvAny $tok $_.Name

        show_progress
        $Win.Title =  "Removing group '" + $grp + "' from workspace " + $_.Name
        #start-sleep -Milliseconds 1000
        Write-Host("Removing group '" + $grp + "' from workspace '" + $_.Name + "'." )
        try{
            # Create a backup
            createGroupBackup $tok $grp
            Remove-DatabricksGroup -BearerToken $tok -GroupName $grp
            #Invoke-DatabricksAPI -BearerToken $tk -API "api/2.0/v2/groups/delete --data '{ \"group_name\": " + $grp + "}'" -Method POST
            #start-sleep -Milliseconds 500
            #showMsg ("Group " + $grp + " removed from workspace " + $_.Name)
        }
        catch [Exception]{
            Write-Debug $_
        }    
    }
    hide_progress
    showMsg("Removed group " + $grp + " from all listed workspaces.")
})



#------------------------------------------------ CHECK CLUSTERS ----------------------------------------------------------------------------

$var_CheckClustersB.Add_Click({

    if( $var_SearchResultsB.Items.Count -eq 0){
        $msg = "No Workspace to process!"
        showErrMsg ($msg)
        return;
    }  
    $var_ResultsClustersB.Clear()
    $var_ResultsClustersB.Foreground = 'darkblue'
    show_progress
    $Win.Title = "Checking Clusters states..."

    $runningList = @()
    $startingList = @()
    $resizingList = @()
    $notrespondingList = @()
    $pendingList = @()

    $global:results | ForEach-Object{

        $tok = $dbksTokens[$_.Name] 
        set-DbxEnvAny $tok $_.Name

        $clusters = Get-DatabricksCluster   
        $ctxt = 'CHECK CLUSTERS FOR ' + $_.Name 
        print_clusters  $ctxt $clusters

        $wk = $_.Name
        foreach ( $cl in $clusters ){
            $Win.Title = "Checking Cluster " + $cl.cluster_name
            Write-Host $cl.cluster_name $cl.state
            $entry = ($wk + ': ' + $cl.cluster_name + '; ')
            switch( $cl.state ){
                'RUNNING'                { $runningList       += $entry }
                'DRIVER_NOT_RESPONDING'  { $notrespondingList += $entry }
                'RESIZING'               { $resizingList      += $entry }
                'STARTING'               { $startingList      += $entry }
                'RESTARTING'             { $startingList      += $entry }
                'PENDING'                { $pendingList       += $entry }
            }
        } # end inner loop

    } # end outer loop
    

    # Print all results
    print_list $runningList 'RUNNING'
    print_list $startingList 'STARTING/RESTARTING'
    print_list $resizingList 'RESIZING'
    print_list $notrespondingList 'DRIVER_NOT_RESPONDING'
    print_list $pendingList 'PENDING'

    if($runningList.Count -eq 0 -and $startingList.Count -eq 0 -and $resizingList.Count -eq 0 -and $notrespondingList.Count -eq 0 -and  $pendingList.Count -eq 0){
        $var_ResultsClustersB.AddText('All clusters are in TERMINATED or TERMINATING state.')
    }

    hide_progress

    # Report generation
    add_to_report $global:ClusterCheck $var_ResultsClustersB

})





#------------------------------------------------ CHECK FAILURES ---------------------------------------------------------------------------------

$var_CheckJobsB.Add_Click({

    if( $var_SearchResultsB.Items.Count -eq 0){
        $msg = "No Workspace to process!"
        showErrMsg ($msg)
        return;
    }  
    $var_ResultsJobsB.Clear()
    $var_ResultsJobsB.Foreground = 'darkblue'
    show_progress
    $Win.Title = "Checking For errors..."
    $nl = [System.Environment]::NewLine

    $global:results | ForEach-Object{

        $tok = $dbksTokens[$_.Name] 
        set-DbxEnvAny $tok $_.Name
        
        $ctxt = 'CHECK FAILURES FOR ' + $_.Name 
        $errList = @()

        $clist =  Get-DatabricksCluster 
        print_clusters  $ctxt $clist
        # print_jobs  $ctxt $jlist
        # CLUSTERS
        foreach($cl in $clist){
            $Win.Title = "Checking Cluster " + $cl.cluster_name
            if($cl.state -ne 'RUNNING'){
                $termType = ($cl.termination_reason).type
                $termCode= ($cl.termination_reason).code
                # One dot for each check on a non-running job
                #$var_ResultsJobsB.AppendText('.')
                if( ($termType -ne 'SUCCESS') -and (is_set $termCode)  -and (is_set $termType) ){
                    $errList += $cl.cluster_name
                    $var_ResultsJobsB.AppendText( $_.Name + ": " + $cl.Cluster_name + ": Code " + $termCode + " - Type: " + $termType + "; " + $nl )
                }
            }
        } # end clusters inner loop

        $jobs =  (DatabricksPS\Get-DatabricksJob) 
        $jtable = @{}
        $jobs | ForEach-Object{
            $jtable.add($_.job_id, $_.settings.name)
        }

        # JOBS
        foreach( $jb in $jtable.GetEnumerator() ){
            $run = DatabricksPS\Get-DatabricksJobRun -JobID $jb.Name  -Limit 1 # only latest run
            if($run.run_id -and $jb.Value -ne 'DLTpipe'){ # exclude existing Delta Live Table in Dev
                $Win.Title = "Checking Job " + $jb.Value
                $output =  DatabricksPS\Get-DatabricksJobRunOutput -JobRunID $run.run_id
                $state = $output.metadata.state.result_state
                $message = $output.metadata.state.state_message
                if($state -eq 'FAILED'){
                    $errList += $jb.Name
                    $var_ResultsJobsB.AppendText( $_.Name + ": " + $jb.Value + ": Job state " + $state )
                    if(is_set $message){
                        $var_ResultsJobsB.AppendText(" - Message: " + $message + ".")
                    }
                    $var_ResultsJobsB.AppendText($nl)
                }
            }
        
        } # end jobs inner loop

    } # end outer loop

    if($errList.Count -eq 0){
        $var_ResultsJobsB.AddText(' No additional failures detected.')
    }

    hide_progress

     # Report generation
     add_to_report $global:ClusterJobsErrors $var_ResultsJobsB
})



#------------------------------------------------ CHECK VMs ---------------------------------------------------------------------------------


$var_CheckVMsB.Add_Click({

    if( $var_SearchResultsB.Items.Count -eq 0){
        $msg = "No Workspace to process!"
        showErrMsg ($msg)
        return;
    }  
    $var_ResultsVMsB.Clear()
    $var_ResultsVMsB.Foreground = 'darkblue'
    show_progress
    $Win.Title = "Checking For VMs..."
    $nl = [System.Environment]::NewLine

    $global:results | ForEach-Object{

        $tok = $dbksTokens[$_.Name] 
        set-DbxEnvAny $tok $_.Name
        # VMs used per dbx
        $vmUsed = @()
        $clist =  Get-DatabricksCluster 
        # CLUSTERS
        foreach($clu in $clist){
            $driver = $clu.driver_node_type_id
            $worker = $clu.node_type_id
            if( ! $vmUsed.Contains($driver)){
                $vmUsed += $driver
            }
            if( ! $vmUsed.Contains($worker)){
                    $vmUsed += $worker
            }
        } # end clusters inner loop
        
        $var_ResultsVMsB.AppendText( $_.Name + ": " + $nl )
        $vmUsed | ForEach-Object {
            $var_ResultsVMsB.AppendText( $_ + $nl)
        }
        $var_ResultsVMsB.AppendText($nl)
    }
      
    hide_progress

     # Report generation
     add_to_report $global:VMTypeCheck $var_ResultsVMsB
})


#------------------------------------------------ CHECK RUNTIME -----------------------------------------------------------------------------

$var_CheckRTsB.Add_Click({

    if( $var_SearchResultsB.Items.Count -eq 0){
        $msg = "No Workspace to process!"
        showErrMsg ($msg)
        return;
    }  
    $var_ResultsRTsB.Clear()
    $var_ResultsRTsB.Foreground = 'darkblue'
    show_progress
    $Win.Title = "Checking For Runtime versions..."
    $nl = [System.Environment]::NewLine

    $global:results | ForEach-Object{

        $tok = $dbksTokens[$_.Name] 
        set-DbxEnvAny $tok $_.Name
        # Runtimes used per dbx
        $runtimes = @()
        $clist =  Get-DatabricksCluster 
        # CLUSTERS
        foreach($clu in $clist){
            $version = $clu.spark_version
            if( ! $runtimes.Contains($version)){
                    $runtimes += $version
            }
        } # end clusters inner loop

        $var_ResultsRTsB.AppendText( $_.Name + ": " + $nl )
        $runtimes | ForEach-Object {
            $var_ResultsRTsB.AppendText( $_ + $nl)
        }
        $var_ResultsRTsB.AppendText($nl)
    } 
    hide_progress

     # Report generation
     add_to_report $global:RuntimeCheck $var_ResultsRTsB
})


#------------------------------------------------ Generate REPORT -----------------------------------------------------------------------------

$var_ReportGen.Add_Click({

    if( $var_SearchResultsB.Items.Count -eq 0){
        $msg = "No Workspace to process!"
        showErrMsg ($msg)
        return;
    }  
    Import-Module ./reporting.ps1 -Force
})



# All code before this  
$Null = $window_bk.ShowDialog()