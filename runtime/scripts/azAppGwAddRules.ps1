# Import needed modules
if (-not (Get-Module Outsystems.SetupTools -ListAvailable)) {
    Write-Output "Module OutSystems.SetupTools not installed. Trying to install"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module -Name Outsystems.SetupTools -Force | Out-Null
}
Import-Module Outsystems.SetupTools -ArgumentList $true, 'Containers' | Out-Null

# Variables
$envAddress = $("$env:os_address")
$appGwName = $("$env:az_appGw")
$appGwResourceGroup = $("$env:az_appGwResourceGroup")
$appGwHttpSettingsName = $("$env:az_appGwHttpSettings")
$appGwBackendPoolName = $("$env:az_appGwBackendPool")
$appGwPathMap = $("$env:az_appGwPathMap")
$scUser = $("$env:os_serviceCenterUser")
$scPass = $("$env:os_serviceCenterPass")
$scCred = New-Object System.Management.Automation.PSCredential ($scUser, $(ConvertTo-SecureString $scPass -AsPlainText -Force))
$appName = $("$env:os_applicationName")

Write-Output "Configuring Application Gateway $appGwName on resource group $appGwResourceGroup"
Write-Output "BackendPool: $appGwBackendPoolName"
Write-Output "HttpSettings: $appGwHttpSettingsName"
Write-Output "PathMap: $appGwPathMap"

# Get application gateway objects
$appGw = Get-AzureRmApplicationGateway -Name $appGwName -ResourceGroupName $appGwResourceGroup
$appGwBackendHttpSettings = Get-AzureRmApplicationGatewayBackendHttpSettings -ApplicationGateway $appGw -Name $appGwHttpSettingsName
$appGwBackendPool = Get-AzureRmApplicationGatewayBackendAddressPool -ApplicationGateway $appGw -Name $appGwBackendPoolName
$pathMap = Get-AzureRmApplicationGatewayUrlPathMapConfig -ApplicationGateway $appGw -Name $appGwPathMap

# Get the app modules from service center
Write-Output "Getting modules of application $appName"
$modules = $(Get-OSPlatformApplications -Credential $scCred -ServiceCenter $envAddress -Filter {$_.Name -eq $appName}).Modules | Select-Object -Property Name
Write-Output "Found $($modules.Count) modules"

# Remove rules if any
Write-Output "Removing existing app rules if any"
$pathMap.PathRules = $pathMap.PathRules | Where-Object -FilterScript {$_.Name -notlike "$($appName)_*"}

# Add the rules
foreach ($module in $modules)
{
    Write-Output "Adding rule for module $($module.name)"
    $newPathRule = New-AzureRmApplicationGatewayPathRuleConfig -Name "$($appName)_$($module.name)" -Paths "/$($module.name)/*" -BackendAddressPool $appGwBackendPool -BackendHttpSettings $appGwBackendHttpSettings
    $pathMap.PathRules += $newPathRule
}

# Export appgw config to artifacts
$appgw | ConvertTo-Json -Depth 30 | Out-File "$($env:Build_ArtifactStagingDirectory)/applicationGateway.json"

# Apply the config to the appgw
Set-AzureRmApplicationGateway -ApplicationGateway $appgw