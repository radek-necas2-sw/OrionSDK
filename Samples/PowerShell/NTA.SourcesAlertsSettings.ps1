# This sample script demonstrates how to:
#       - add and manage Netflow Flow Sources and CBQoS sources with required Nodes and interfaces 
#       - manage Netflow alerts
#       - configure some Netflow related settings 
#       - download router configuration via NCM to verify Netflow configuration on the router
#
# Please update the hostname and credential setup to match your configuration.
# To manage Flow or CBQoS Sources you need to be logget as a user with enabled Allow Node Management Rights.
# To manage Settings you need admin rights. Alert management requires Allow Alert Management Rights.


# Connect to SWIS
$hostname = "swis-machine-hostname"                     # Update to match your configuration
$username = "admin"                                     # Update to match your configuration
$password = New-Object System.Security.SecureString     # Update to match your configuration
$cred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
$swis = Connect-Swis -host $hostname -cred $cred

# Default engine ID
$engineId = 1

# #################### Create enabled Netflow Sources #######################

# Create Orion Node
# Update to match your configuration
$nodeCaption = "my.netflownode.corp"
$newSNMPV2NodeProps = @{
    IPAddress = "1.1.1.1";
    EngineID = $engineId;
    Caption = $nodeCaption;
    ObjectSubType ='SNMP';
    Community = "public";
    SNMPVersion = 2;
    DNS = "";
    SysName = "";
}
New-SwisObject $swis -EntityType Orion.Nodes -Properties $newSNMPV2NodeProps
$nodeId = Get-SwisData $swis "SELECT NodeID FROM Orion.Nodes WHERE Caption = '$nodeCaption'"
Write-Host("New node with ID $nodeId created")

# Discover and create interfaces for Node
$discovered = Invoke-SwisVerb $swis Orion.NPM.Interfaces DiscoverInterfacesOnNode $nodeId
if($discovered.Result -ne "Succeed")
{
    Write-Error "Interface discovery for node with ID $nodeId failed" -ErrorAction Stop
}
Invoke-SwisVerb $swis Orion.NPM.Interfaces AddInterfacesOnNode @($nodeId, $discovered.DiscoveredInterfaces, 'AddDefaultPollers') | Out-Null
$interfaceIds = Get-SwisData $swis "SELECT InterfaceID FROM Orion.NPM.Interfaces WHERE NodeID = $nodeID"
$interfaceIds = $interfaceIds |% {[int]$_}
Write-Host("Discovered $($interfaceIds.Count) interfaces for new node with ID $nodeId")

# Enable Flow Collection on every interface of the router - Create Netflow Sources
Invoke-SwisVerb $swis Orion.Netflow.Source EnableFlowSources @(,$interfaceIds) | Out-Null
$flowSourcesIds = Get-SwisData $swis "SELECT NetflowSourceID FROM Orion.Netflow.Source WHERE NodeID = $nodeID"
Write-Host("$($flowSourcesIds.Count) Netflow Sources created")

# ############################# Create enabled CBQoS Sources #####################################

# Create Orion Node
# Update to match your configuration
$nodeCaption = "my.cbqosnode.corp"
$newSNMPV2NodeProps = @{
    IPAddress = "1.1.1.2";
    EngineID = $engineId;
    Caption = $nodeCaption;
    ObjectSubType ='SNMP';
    Community = "public";
    SNMPVersion = 2;
    DNS = "";
    SysName = "";
}
New-SwisObject $swis -EntityType Orion.Nodes -Properties $newSNMPV2NodeProps | Out-Null
$nodeId = Get-SwisData $swis "SELECT NodeID FROM Orion.Nodes WHERE Caption = '$nodeCaption'"
Write-Host("New node with ID $nodeId created")

# Discover and create interfaces for Node
$discovered = Invoke-SwisVerb $swis Orion.NPM.Interfaces DiscoverInterfacesOnNode $nodeId
if($discovered.Result -ne "Succeed")
{
    Write-Error "Interface discovery for node with ID $nodeId failed" -ErrorAction Stop
}
Invoke-SwisVerb $swis Orion.NPM.Interfaces AddInterfacesOnNode @($nodeId, $discovered.DiscoveredInterfaces, 'AddDefaultPollers') | Out-Null
$interfaceIds = Get-SwisData $swis "SELECT InterfaceID FROM Orion.NPM.Interfaces WHERE NodeID = $nodeID"
Write-Host("Discovered $($interfaceIds.Count) interfaces for new node with ID $nodeId")

# Create enabled CBQoS Sources for every interface on the node
foreach ($interfaceId in $interfaceIds)
{
    $newCBQoSSourceProps = @{
        NodeID = $nodeId;
        InterfaceID = $interfaceId;
        EngineID = $engineId;
        Enabled = $true;
    }
    New-SwisObject $swis -EntityType Orion.Netflow.CBQoSSource -Properties $newCBQoSSourceProps | Out-Null
}
$cbqosSourcesIds = Get-SwisData $swis "SELECT CBQoSSourceID FROM Orion.Netflow.CBQoSSource WHERE NodeID = $nodeID"
Write-Host("$($cbqosSourcesIds.count) enabled CBQoS Sources created")

# ####################### Enable/Disable CBQoS and Flow Sources ####################################

# Disable Flow Sources
$nodeId = Get-SwisData $swis "SELECT NodeID FROM Orion.Nodes WHERE Caption = '3850.hobbylobby.corp'"
$flowSourcesIds = Get-SwisData $swis "SELECT NetflowSourceID FROM Orion.Netflow.Source WHERE NodeID = $nodeID"
$flowSourcesIds = $flowSourcesIds |% {[int]$_}
Invoke-SwisVerb $swis Orion.Netflow.Source DisableFlowSources @(,$flowSourcesIds) | Out-Null
$disableflowSourcesIds = Get-SwisData $swis "SELECT NetflowSourceID FROM Orion.Netflow.Source WHERE NodeID = $nodeID and Enabled = false"
Write-Host("Disabled $($disableflowSourcesIds.Count) Flow Sources for node with ID $nodeId. Total interface count $($flowSourcesIds.Count)")

# Enable Flow Sources
Invoke-SwisVerb $swis Orion.Netflow.Source EnableFlowSources @(,$flowSourcesIds) | Out-Null
$enabledflowSourcesIds = Get-SwisData $swis "SELECT NetflowSourceID FROM Orion.Netflow.Source WHERE NodeID = $nodeID and Enabled = true"
Write-Host("Enabled $($enabledflowSourcesIds.Count) Flow Sources for Node with ID $nodeId. Total interface count $($flowSourcesIds.Count)")

# Disable CBQoS Sources
$nodeId = Get-SwisData $swis "SELECT NodeID FROM Orion.Nodes WHERE Caption = 'Cisco CBQoS 2'"
$cbqosSourcesUris = Get-SwisData $swis "SELECT Uri FROM Orion.Netflow.CBQoSSource WHERE NodeID = $nodeID"

$disableProps = @{
    Enabled = $false;
}
foreach ($cbqosSourcesUri in $cbqosSourcesUris)
{
    Set-SwisObject $swis -Uri $cbqosSourcesUri -Properties $disableProps | Out-Null
}
$disableCbqosSourcesIds = Get-SwisData $swis "SELECT CBQoSSourceID FROM Orion.Netflow.CBQoSSource WHERE NodeID = $nodeID and Enabled = false"
Write-Host("Disabled $($disableCbqosSourcesIds.Count) CBQoS Sources for Node with ID $nodeId. Total interface count $($cbqosSourcesUris.Count).")

# Enable CBQoS Sources
$enabledProps = @{
    Enabled = $true;
}
foreach ($cbqosSourcesUri in $cbqosSourcesUris)
{
    Set-SwisObject $swis -Uri $cbqosSourcesUri -Properties $enabledProps | Out-Null
}
$enabledCbqosSourcesIds = Get-SwisData $swis "SELECT CBQoSSourceID FROM Orion.Netflow.CBQoSSource WHERE NodeID = $nodeID and Enabled = true"
Write-Host("Enabled $($enabledCbqosSourcesIds.Count) CBQoS sources for Node with ID $nodeId. Total interface count $($cbqosSourcesUris.Count).")

# ####################### Activate/Deactivate NTA Alert ############################################

$alertUri = Get-SwisData $swis "Select Uri FROM Orion.AlertConfigurations WHERE Name = 'NTA Alert on BRN-DVB-RNECA02'"

# Disable alert
$enabledProps = @{
    Enabled = $false;
}
Set-SwisObject $swis -Uri $alertUri -Properties $enabledProps | Out-Null

# Enable alert
$enabledProps = @{
    Enabled = $true;
}
Set-SwisObject $swis -Uri $alertUri -Properties $enabledProps | Out-Null

# ####################### Change NTA related Orion Settings #########################################

# List available Orion Settings
# Uncomment if you want to get  all available Orion Settings
# Get-SwisData $swis "SELECT SettingID, Name, Description, Units, Minimum, Maximum, CurrentValue, DefaultValue, Hint FROM Orion.Settings"

# Enable/Disable CBQoS polling
$settingId = 'CBQoS_Enabled'
$settingUri = Get-SwisData $swis "SELECT Uri FROM Orion.Settings WHERE SettingID = '$settingId'"
$props = @{
    CurrentValue = 0;   # Change this value to 1 to enable setting
}
Set-SwisObject $swis -Uri $settingUri -Properties $props | Out-Null
$settingUri = Get-SwisData $swis "SELECT CurrentValue FROM Orion.Settings WHERE SettingID = '$settingId'"
Write-Host("Setting $settingId has value $currentValue")

# ####################### Retrieve Configuration file for Netflow Source via NCM ###########################

# Get Orion Node, Interface, Netflow Source information and Router identifiers for concrete Netflow Source
# You can use these alternative conditions
# If you know NetflowSourceID: WHERE S.NetflowSourceID = $netflowSourceId
# If you know NodeName: WHERE N.NodeName = '$nodeName'
# If you know InterfaceName: WHERE I.InterfaceName = '$interfaceName'
$nodeName = "my.netflownode.corp"       # Update to match your configuration
$interfaceName = "GigabitEthernet0/1"   # Update to match your configuration

$query= "
SELECT S.NetflowSourceID, S.NodeID, S.InterfaceID, S.Enabled, S.LastTimeFlow, S.LastTime, S.EngineID, 
    N.NodeName,
    I.Name as InterfaceName, I.Index as RouterIndex
FROM Orion.Netflow.Source S
INNER JOIN Orion.NPM.Interfaces I ON I.InterfaceID = S.InterfaceID
INNER JOIN Orion.Nodes N ON S.NodeID = N.NodeID
WHERE N.NodeName = '$nodeName' AND I.InterfaceName = '$interfaceName'
"
$netflowSourceInfo = Get-SwisData $swis $query
if(!$netflowSourceInfo) 
{
    Write-Error "Netflow Source information not found" -ErrorAction Stop
}

# Works only if NCM is installed
# Retrieve latest NCM configuration file for concrete node identified by Orion Node ID
# You can use it to check node configuration - for example verify Netflow configuration
$orionNodeId = $netflowSourceInfo.NodeID
$query = "
SELECT TOP 1 C.NodeID AS NcmNodeId, N.CoreNodeId, C.DownloadTime, C.ConfigType, C.Config
FROM NCM.ConfigArchive C
INNER JOIN NCM.NodeProperties N ON C.NodeId = N.NodeId
WHERE N.CoreNodeID = $orionNodeId
ORDER BY C.DownloadTime DESC
"

$lastConfigData = Get-SwisData $swis $query
if(!$lastConfigData)
{
    Write-Error "Node with ID $orionNodeId is not configured in NCM or no configuration for this node has been loaded yet" -ErrorAction Stop
}
Write-Host("Configuration for node with name $nodeName, Orion ID $orionNodeId, NCM Node ID = $($lastConfigData.NcmNodeId)")
# Uncomment if you want to write configuration to console
# Write-Host($lastConfigData.Config)

# You can analyze configuration manually or write some parser. To identify data related to concrete Netflow Source 
# you can use retrieved information in $netflowSourceInfo object like: $netflowSourceInfo.InterfaceName, $netflowSourceInfo.RouterIndex
