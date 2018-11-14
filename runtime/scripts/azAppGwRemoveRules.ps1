# Variables
$appGwName = $("$env:az_appGw")
$appGwResourceGroup = $("$env:az_appGwResourceGroup")
$appGwPathMap = $("$env:az_appGwPathMap")
$appName = $("$env:os_applicationName")

Write-Output "Configuring Application Gateway $appGwName on resource group $appGwResourceGroup"
Write-Output "PathMap: $appGwPathMap"

# Get application gateway objects
$appGw = Get-AzureRmApplicationGateway -Name $appGwName -ResourceGroupName $appGwResourceGroup
$pathMap = Get-AzureRmApplicationGatewayUrlPathMapConfig -ApplicationGateway $appGw -Name $appGwPathMap

# Remove rules if any
Write-Output "Removing existing app rules if any"
$pathMap.PathRules = $pathMap.PathRules | Where-Object -FilterScript {$_.Name -notlike "$($appName)_*"}

# Export appgw config to artifacts
$appgw | ConvertTo-Json -Depth 30 | Out-File "$($env:Build_ArtifactStagingDirectory)/applicationGateway.json"

# Apply the config to the appgw
Set-AzureRmApplicationGateway -ApplicationGateway $appgw