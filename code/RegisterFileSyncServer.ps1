param(
    [String]$rgName,
    [String]$sssName,
    [String]$fssName,
    [String]$ssyncGroup
)

# Logging start of script execution
Write-Output "Starting RegisterFileSyncServer.ps1 script execution..."

# Error handling function
function Handle-Error {
    param([String]$errorMessage)
    Write-Error $errorMessage
    exit 1  # Exit script with error code 1
}

try {
    # Validate mandatory parameters
    if (-not $rgName) { Handle-Error "Resource Group name not provided." }
    if (-not $sssName) { Handle-Error "Storage Sync Service name not provided." }
    if (-not $fssName) { Handle-Error "FileSync VM name not provided." }
    if (-not $ssyncGroup) { Handle-Error "Sync Group name not provided." }

    # Disable IE security
    function Disable-InternetExplorerESC {
        $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
        $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
        Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
        Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
        Stop-Process -Name Explorer
        Write-Output "IE Enhanced Security Configuration (ESC) has been disabled." 
    }
    
    Disable-InternetExplorerESC

    # Install required modules
    Install-PackageProvider -Name NuGet -Force
    Install-Module -Name Az -AllowClobber -Force
    Import-Module -Name Az -Force

    # Authenticate using the service principal
    $secureClientSecret = ConvertTo-SecureString $env:ARM_CLIENT_SECRET -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($env:ARM_CLIENT_ID, $secureClientSecret)
    Connect-AzAccount -ServicePrincipal -Tenant $env:ARM_TENANT_ID -Credential $credential

    # Download Azure File Sync agent
    $osver = [System.Environment]::OSVersion.Version
    $msiUri = switch ($osver.Major) {
        10 { switch ($osver.Build) {
                20348 { "https://aka.ms/afs/agent/Server2022" }
                17763 { "https://aka.ms/afs/agent/Server2019" }
                default { Handle-Error "Unsupported OS version for Azure File Sync." }
            }
        }
        6 { switch ($osver.Build) {
                3 { "https://aka.ms/afs/agent/Server2016" }
                9600 { "https://aka.ms/afs/agent/Server2012R2" }
                default { Handle-Error "Unsupported OS version for Azure File Sync." }
            }
        }
        default { Handle-Error "Unsupported OS version for Azure File Sync." }
    }

    Write-Output "Downloading Azure File Sync agent from $msiUri"
    Invoke-WebRequest -Uri $msiUri -OutFile "StorageSyncAgent.msi"

    # Install Azure File Sync agent
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "StorageSyncAgent.msi", "/quiet" -Wait

    # Remove temporary files
    Remove-Item -Path "StorageSyncAgent.msi" -Force

    # Register server with Storage Sync Service
    $serverRegistration = Register-AzStorageSyncServer -ResourceGroupName $rgName -StorageSyncServiceName $sssName
    Write-Output "Server registered successfully: $($serverRegistration.ResourceId)"

    # Create server endpoint
    $serverEndpointPath = "F:\"  # Example path
    $cloudTieringDesired = $true  # Set to $true or $false based on your requirements
    $initialDownloadPolicy = "NamespaceOnly"  # Set your initial download policy

    $syncGroupObject = Get-AzStorageSyncGroup -Name $ssyncGroup -ResourceGroupName $rgName -StorageSyncServiceName $sssName
    $syncGroupId = $syncGroupObject.Id

    if ($cloudTieringDesired) {
        New-AzStorageSyncServerEndpoint -Name $fssName -SyncGroupResourceId $syncGroupId -ServerResourceId $serverRegistration.ResourceId `
                                        -ServerLocalPath $serverEndpointPath -CloudTiering -VolumeFreeSpacePercent 70 `
                                        -InitialDownloadPolicy $initialDownloadPolicy -InitialUploadPolicy "Merge"
    } else {
        New-AzStorageSyncServerEndpoint -Name $fssName -SyncGroupResourceId $syncGroupId -ServerResourceId $serverRegistration.ResourceId `
                                        -ServerLocalPath $serverEndpointPath -InitialDownloadPolicy $initialDownloadPolicy
    }
    Write-Output "Server endpoint created successfully."
}
catch {
    Handle-Error "An error occurred: $_"
}

# Exit with success code
exit 0
