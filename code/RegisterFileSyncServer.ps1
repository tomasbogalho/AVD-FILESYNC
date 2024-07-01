
param([String]$rgName = "rgName",[String]$sssName = "sssName", [String]$fssName = "fssName", [String]$ssyncGroup = "ssyncGroup" )

# Variables
$clientId = $env:ARM_CLIENT_ID
$tenantId = $env:ARM_TENANT_ID
$clientSecret = $env:ARM_CLIENT_SECRET

$resourceGroupName = $rgName
$storageSyncServiceName = $sssName
$serverName = $fssName
$SyncGroup = $ssyncGroup

# Disable IE security on Windows Server via PowerShell - source: https://stackoverflow.com/questions/9368305/disable-ie-security-on-windows-server-via-powershell

function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}
function Enable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 1
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 1
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been enabled." -ForegroundColor Green
}
function Disable-UserAccessControl {
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
    Write-Host "User Access Control (UAC) has been disabled." -ForegroundColor Green    
}

Disable-InternetExplorerESC

Install-Module Az -Force -Confirm:$false
Import-Module AZ -Force -Confirm:$false

# Authenticate using the service principal
$secureClientSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($clientId, $secureClientSecret)
Connect-AzAccount -ServicePrincipal -Tenant $tenantId -Credential $credential

# Gather the OS version - from https://medium.com/@mrciosousacunha/azure-file-sync-444e4c8e01bb
$osver = [System.Environment]::OSVersion.Version

# Download the appropriate version of the Azure File Sync agent for your OS.
if ($osver.Equals([System.Version]::new(10, 0, 20348, 0))) {
 Invoke-WebRequest `
 -Uri https://aka.ms/afs/agent/Server2022 `
 -OutFile "StorageSyncAgent.msi" 
} elseif ($osver.Equals([System.Version]::new(10, 0, 17763, 0))) {
 Invoke-WebRequest `
 -Uri https://aka.ms/afs/agent/Server2019 `
 -OutFile "StorageSyncAgent.msi" 
} elseif ($osver.Equals([System.Version]::new(10, 0, 14393, 0))) {
 Invoke-WebRequest `
 -Uri https://aka.ms/afs/agent/Server2016 `
 -OutFile "StorageSyncAgent.msi" 
} elseif ($osver.Equals([System.Version]::new(6, 3, 9600, 0))) {
 Invoke-WebRequest `
 -Uri https://aka.ms/afs/agent/Server2012R2 `
 -OutFile "StorageSyncAgent.msi" 
} else {
 throw [System.PlatformNotSupportedException]::new("Azure File Sync is only supported on Windows Server 2012 R2, Windows Server 2016, Windows Server 2019 and Windows Server 2022")
}
# Install the MSI. Start-Process is used to PowerShell blocks until the operation is complete.

# Note that the installer currently forces all PowerShell sessions closed - this is a known issue.
Start-Process -FilePath "StorageSyncAgent.msi" -ArgumentList "/quiet" -Wait

# Note that this cmdlet will need to be run in a new session based on the above comment.
# You may remove the temp folder containing the MSI and the EXE installer
Remove-Item -Path ".\StorageSyncAgent.msi" -Recurse -Force

# Register the server with Storage Sync Service
$serverRegistration = Register-AzStorageSyncServer -ResourceGroupName $resourceGroupName -StorageSyncServiceName $storageSyncServiceName 

# Output the server registration details
$serverRegistration

$serverRegistration.ResourceId

# Creating a Volume on disk
Get-Disk | Where-Object "Number" -eq '2'|
         Initialize-Disk -PartitionStyle GPT -PassThru |
            New-Volume -FileSystem NTFS -DriveLetter F -FriendlyName 'New-Volume'


# Create a server endpoint
$serverEndpointPath = "F:\"
$cloudTieringDesired = $true
$volumeFreeSpacePercentage = 70

# Optional property. Choose from: [NamespaceOnly] default when cloud tiering is enabled. [NamespaceThenModifiedFiles] default when cloud tiering is disabled. [AvoidTieredFiles] only available when cloud tiering is disabled.
$initialDownloadPolicy = "NamespaceOnly"
$initialUploadPolicy = "Merge"

# Optional property. Choose from: [Merge] default for all new server endpoints. Content from the server and the cloud merge. This is the right choice if one location is empty or other server endpoints already exist in the sync group. [ServerAuthoritative] This is the right choice when you seeded the Azure file share (e.g. with Data Box) AND you are connecting the server location you seeded from. This enables you to catch up the Azure file share with the changes that happened on the local server since the seeding.

if ($cloudTieringDesired) {
    # Ensure endpoint path is not the system volume
    $directoryRoot = [System.IO.Directory]::GetDirectoryRoot($serverEndpointPath)
    $osVolume = "$($env:SystemDrive)\"
    if ($directoryRoot -eq $osVolume) {
        throw [System.Exception]::new("Cloud tiering cannot be enabled on the system volume")
    }
# get syncgorup id
$syncGroup = $(Get-AzStorageSyncGroup -Name $SyncGroup -ResourceGroupName $resourceGroupName -StorageSyncServiceName $storageSyncServiceName)

# Create server endpoint
    New-AzStorageSyncServerEndpoint -Name $serverName -SyncGroup $syncGroup -ServerResourceId $ServerRegistration.ResourceId -ServerLocalPath $serverEndpointPath -CloudTiering -VolumeFreeSpacePercent $volumeFreeSpacePercentage -InitialDownloadPolicy $initialDownloadPolicy -InitialUploadPolicy $initialUploadPolicy
} else 
{
    # Create server endpoint
    New-AzStorageSyncServerEndpoint -Name $serverName -SyncGroup $syncGroup -ServerResourceId $ServerRegistration.ResourceId -ServerLocalPath $serverEndpointPath -InitialDownloadPolicy $initialDownloadPolicy
}

