[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    $VSTSAccount,
    $PersonalAccessToken,
    $PoolName
)

$gitRepoName = "Microsoft/azure-pipelines-agent"
$serverUrl = "https://dev.azure.com/$VSTSAccount"
$installDir = "C:\VSTSAgent"

# Download latest version to %TEMP%
Write-Verbose "Downloading latest AzDevOps agent" -Verbose
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$latestVersion = $(Invoke-RestMethod -Uri "https://api.github.com/repos/$gitRepoName/releases/latest").tag_name
$downloadUrl = ((Invoke-RestMethod -Uri "https://github.com/$gitRepoName/releases/download/$latestVersion/assets.json") -match 'win-x64').downloadurl
(New-Object System.Net.WebClient).DownloadFile($downloadUrl, "$env:TEMP\agent.zip")

# Create installdir and work folder
Write-Verbose "Creating agent folder" -Verbose
New-Item -ItemType Directory -Path $installDir -Force
New-Item -ItemType Directory -Path "$installDir/_work" -Force

# Extract agent
Write-Verbose "Expanding binaries" -Verbose
Expand-Archive "$env:TEMP\agent.zip" -DestinationPath $installDir -Force

# Configuring the agent
Write-Verbose "Configuring agent" -Verbose
Push-Location -Path $installDir

# Setup the agent as a service
.\config.cmd --unattended --url $serverUrl --auth PAT --token $PersonalAccessToken --pool $PoolName --agent $env:COMPUTERNAME --runasservice

Pop-Location

Write-Verbose "Agent install output: $LASTEXITCODE" -Verbose
Write-Verbose "Exiting InstallVSTSAgent.ps1" -Verbose

exit $LASTEXITCODE