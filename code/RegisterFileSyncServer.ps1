
param([String]$rgName = "rgName")
param([String]$sssName = "sssName")
param([String]$fssName = "fssName")
# Variables

$clientId = $env:ARM_CLIENT_ID
$tenantId = $env:ARM_TENANT_ID
$clientSecret = $env:ARM_CLIENT_SECRET

$resourceGroupName = $rgName
$storageSyncServiceName = $sssName
$serverName = $fssName

# Output the details
$clientId
$tenantId
$clientSecret


# Authenticate using the service principal
$secureClientSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($clientId, $secureClientSecret)
Connect-AzAccount -ServicePrincipal -Tenant $tenantId -Credential $credential

# Register the server with Storage Sync Service
$serverRegistration = Register-AzStorageSyncServer -ResourceGroupName $resourceGroupName `
    -StorageSyncServiceName $storageSyncServiceName -ServerName $serverName

# Output the server registration details
$serverRegistration
