# DBX-Admin
MS Azure Databricks cross-workspace administration

<img width="412" alt="image" src="https://user-images.githubusercontent.com/97665470/149491043-a90de3eb-2fa8-4634-839c-80cfb362448f.png">

### Motivation
Provide an extensible GUI for administrating Databricks (DBX) Workspaces, in order to ease user administration and DBX jobs/clusters oversight.

### License
**GNU GPLv3** lets people do almost anything they want, _except distributing closed source versions_, as sharing improvements on this tool would be useful to everyone.
 
### Advantages
Easier and speedier DBX admin tasks, such as:
- Finding/Adding/Removing users, including across workspaces
- Adding/Removing groups, including across workspaces
- Monitoring all the cluster states and providing actions like Start/Restart/Stop/Delete clusters
- Detecting orphaned users that do not belong to any group, and correct (either add to an existing group or remove)
- Allows cross-subscription and cross-workspace administration & oversight, e.g. running clusters, job failures, VM types & DBS Runtime used.
- Scales with the number of subscriptions, workspaces etc.
- Dynamic and independent from the number of subscriptions, workspaces, groups, users and clusters – makes minimal assumptions
- Secured via Azure AD login and Key Vault.
- Adaptable via configuration, i.e. specify Key Vault where secret DBX tokens are stored, Workspace list filters, etc.

### Real world scenarios
DBX-Admin has been used in several real-world use cases, like:
#### User administration
- Add a new Data Scientist to all the corresponding groups in the different environments (Dev,Test, Prod)
- Add a group of new Analysts on the project in all the corresponding groups and environments

Instead of having to login to each workspace to add/remove each group or user, the tool will insert/remove in bulk, and in seconds.
#### Cluster/Jobs/VMs/Runtimes monitoring
- Generate an audit report in MS Word (or plain text) of the results obtained below in all or subset (e.g., only prod) of workspaces:
   - Provide a list of clusters running at this time, per workspace
   - List all cluster/job failures per workspace
   - List all the different VM types used per workspace
   - List all the different DBX runtime versions used per workspace

### Present day limitations
- Works only with MS Azure cloud 
- Works with DBX tokens only
- Works with only two Azure regions at a time
- The UI is mostly single-threaded, as secondary WPF windows need to be closed before switching back to the main window. That said, Powershell grid-views are being used wherever they make sense to address that particular limitation. Multi-threading is also being added to parts of the code needing instant refreshing (e.g. color change when cluster state  changes from stopped to started and vice-versa). 

### Credits
This tool uses a couple of existing open-source Powershell DBX modules:
- [DataThirstLtd](https://github.com/DataThirstLtd/azure.databricks.cicd.tools)
- [gbrueckl](https://github.com/gbrueckl/Databricks.API.PowerShell)

### Prerequisites
- The tool uses Azure AD login, so the user should have the required permissions to view the subscriptions, workspaces, etc.
- The tool uses DBX tokens, therefore there is still a manual step of getting those tokens and storing them in an Azure Key Vault, where the tool will look for them on startup.

### Design
The DBX-Admin tool uses Powershell, Azure Key Vault, WPF/XAML and a couple existing DBX modules that call the DBX Rest API. It is designed merely to complement the DBX UI, not to replace it. 

<img width="413" alt="image" src="https://user-images.githubusercontent.com/97665470/149494475-f7dd19d0-2d20-4adb-bc6a-933c89189378.png">

The general design can be viewed in a tree-like manner, coming down from Azure subscriptions to DBX workspaces, clusters/jobs, groups and users:

<img width="437" alt="image" src="https://user-images.githubusercontent.com/97665470/149494709-6341bcbb-8005-42da-b1d2-e67b947adf7c.png">

Finally, this tool was designed to be simple to use. Tool tips are available at various places in the UI to help. Button labels in brown reddish color indicate cross-workspace operations from the Main window. Other actions are workspace-specific.

_Caching_ happens in a number of places to speed up retrieval. It is still minimized since the tool needs to be as dynamic/real-time as possible.

### Quickstart
1. Create the DBX tokens of the workspaces to administrate
2. Store the tokens in an Azure key vault following the naming convention _\<workspace name\>-tk_ as key vault secret keys.
3. Edit _dbx-admin-config.txt_ by entering the Key Vault name, workspace filters regex and the Azure regions.
4. Start the tool by running the main file _dbx-admin.ps1_ with Powershell. 
  
**Note**: The start up process will be slow, specially the first time, since missing modules will need to be installed by the tool if not present. Subsequent starts will be faster, though the tool will still need to retrieve the tokens from the key vault each time it starts.

