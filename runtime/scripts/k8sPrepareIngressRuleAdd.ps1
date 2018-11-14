# Import needed modules
if (-not (Get-Module Outsystems.SetupTools -ListAvailable)) {
    Write-Output "Module OutSystems.SetupTools not installed. Trying to install"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    Install-Module -Name Outsystems.SetupTools -Force | Out-Null
}
Import-Module Outsystems.SetupTools -ArgumentList $true, 'Containers' | Out-Null

# Init variables
$appName = $("$env:os_applicationName")
$envAddress = $("$env:os_address")
$file = "$($env:Build_ArtifactStagingDirectory)/ingressRules.json"
$scUser = $("$env:os_serviceCenterUser")
$scPass = $("$env:os_serviceCenterPass")
$scCred = New-Object System.Management.Automation.PSCredential ($scUser, $(ConvertTo-SecureString $scPass -AsPlainText -Force))

# Load the current ingress controller config from the previous task
Write-Output "Loading current ingress rules from the previous task"
$ingressDefinition = $env:k8s_KubectlOutput | ConvertFrom-Json

# Get host rules
$rulesFromHost = $ingressDefinition.spec.rules | Where-Object -FilterScript {$_.host -eq "$envAddress"}

# If host doesnt exist, add a new one
Write-Output "Check if host $envAddress already exists."
if (-not $rulesFromHost) {
    Write-Output "Host $envAddress doesnt exists. Adding a new entry"
    $rule = [pscustomobject]@{
        host = $envAddress
        http = [pscustomobject]@{
            paths = @()
        }
    }
    $ingressDefinition.spec.rules += $rule

    # Get rules again after adding the host
    $rulesFromHost = $ingressDefinition.spec.rules | Where-Object -FilterScript {$_.host -eq "$envAddress"}
}
else 
{
    # Remove all rules where the service matches the app name
    Write-Output "Removing all rules where service matches the app $appName on host $envAddress"
    $rulesFromHost.http.paths = $rulesFromHost.http.paths | Where-Object -FilterScript {$_.backend.serviceName -ne $appName}
    if (-not $rulesFromHost.http.paths){
        $rulesFromHost.http.paths = @()
    }
}

# Get the app modules from service center
Write-Output "Getting modules of application $appName"
$modules = $(Get-OSPlatformApplications -Credential $scCred -ServiceCenter $envAddress -Filter {$_.Name -eq $appName}).Modules | Select-Object -Property Name
Write-Output "Found $($modules.Count) modules"

# Add the rules
foreach ($module in $modules)
{
    Write-Output "Adding rule for module $($module.name)"
    $newRule = [pscustomobject]@{
        path    = "/$($module.name)/.*"
        backend = [pscustomobject]@{
            serviceName = $($appName.toLower())
            servicePort = 80
        }
    }
    $rulesFromHost.http.paths += $newRule
}

# Save file
Write-Output  "Writting result configuration to $file"
Set-Content -Path $file -Value $($ingressDefinition | ConvertTo-Json -Depth 10)