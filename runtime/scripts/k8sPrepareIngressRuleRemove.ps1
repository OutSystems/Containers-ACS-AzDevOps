# Init variables
$appName = $("$env:os_applicationName")
$envAddress = $("$env:os_address")
$file = "$($env:Build_ArtifactStagingDirectory)/ingressRules.json"

# Load the current ingress controller config from the previous task
Write-Output "Loading current ingress rules from the previous task"
$ingressDefinition = $env:k8s_KubectlOutput | ConvertFrom-Json

# Get host rules
$rulesFromHost = $ingressDefinition.spec.rules | Where-Object -FilterScript {$_.host -eq "$envAddress"}

# Remove all rules where the service matches the app name
Write-Output "Removing all rules where service matches the app $appName"
$rulesFromHost.http.paths = $rulesFromHost.http.paths | Where-Object -FilterScript {$_.backend.serviceName -ne $appName} 

# If host doesnt contains any rule, remove it
if(-not $rulesFromHost.http.paths)
{
    Write-Output "Host $envAddress doesnt have any paths. Removing the host"
    $remainingRules = @()
    $remainingRules += $ingressDefinition.spec.rules | Where-Object -FilterScript {$_.host -ne "$envAddress"}
    $ingressDefinition.spec.rules = $remainingRules
}

# Save file
Write-Output  "Writting result configuration to $file"
Set-Content -Path $file -Value $($ingressDefinition | ConvertTo-Json -Depth 10)