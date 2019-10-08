# This sample script demonstrates how to download configuration for Router
# from NCM. You can use it to verify Netflow related configuration on the Router.


# Connect to SWIS
$hostname = "swis-machine-hostname"                     # Update to match your configuration
$username = "admin"                                     # Update to match your configuration
$password = New-Object System.Security.SecureString     # Update to match your configuration
$cred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
$swis = Connect-Swis -host $hostname -cred $cred

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
