  ########################################################################################
#### Powershell Script to suppress AppDynamics machine agent alerts for current server
########################################################################################


# Initiatize the connection parameters
$controller = ""
$serverId = ""
$USERNAME = ""
$PASSWORD = ""


# Check if AppDynamics Machine Agent is running on this server to trigger action suppression.
$serviceName = "Appdynamics Machine Agent"

# Get the service object
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

# Check if the service object exists and if it's running
if ($service -ne $null -and $service.Status -eq "Running") {
    Write-Host "The service '$serviceName' is running."
    # Obtain Machine Agent Install Path
    # Get the service object
    $serviceObject = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"


    Write-Host "Service Path: $($serviceObject.PathName)"

    # Use Split-Path to separate the path into its components
    $FilePath = (Split-Path -Path $($serviceObject.PathName)) + "\MachineAgentService.vmoptions"
    Write-Host "Service Path: $FilePath"

    #$results = Select-String -Path $FilePath -Pattern "appdynamics.controller.hostName" -SimpleMatch
    $results = Get-Content $FilePath | Where-Object {$_ -like "*appdynamics.controller.hostName*"}

    if ($results -ne $null) {

        $controller = $results.split("=")[1]
        Write-Host "Controller Host: $controller"

        $results = Get-Content $FilePath | Where-Object {$_ -like "*appdynamics.agent.accountName*"}
        $accountName = $results.split("=")[1]
        $USERNAME = $USERNAME + "@" + $accountName
        Write-Host "Controller Account: $accountName"

        $proxy = $false

        $results = Get-Content $FilePath | Where-Object {$_ -like "*appdynamics.http.proxyHost*"}
        if ($results -ne $null) {
            $proxyHost = $results.split("=")[1]
            $proxy = $true
            Write-Host "Controller Proxy Host: $proxyHost"
        }
        $results = Get-Content $FilePath | Where-Object {$_ -like "*appdynamics.http.proxyPort*"}
        if ($results -ne $null) {
            $proxyPort = $results.split("=")[1]
            Write-Host "Controller Proxy Port: $proxyPort"
        }

        # Retrieve Server Application Id
        $credPair = "$($USERNAME):$($PASSWORD)"
        $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
 
 
        # Define headers if needed
        $headers = @{
            "Content-Type" = "application/json"
            'Authorization' = "Basic $encodedCredentials"
        }

        $uri = "https://" + $controller + "/controller/rest/applications/Server%20%26%20Infrastructure%20Monitoring"
        $uri

        if ($proxy) {
            $response = Invoke-WebRequest -Uri $uri -Method Get -Proxy ${proxyHost}:${proxyPort} -Headers $headers
        } else {
            $response = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers
        }

        $response.StatusCode
        $response.Content   
        
        $serverId = ([xml]$response.Content).applications.application.id
        Write-Host "Server ID: $serverId"    
        
        # Get the current date and time
         # Get the local timezone
        $localTimeZone = [System.TimeZoneInfo]::Local
        $timezone = $($localTimeZone.Id) 

        $currentDateTime = (Get-Date)
        
        # Format the date
        $dateString = $currentDateTime.ToString("yyyy-MM-ddTHH:mm:ss")
        
        $uri = "https://"+ $controller + "/controller/alerting/rest/v1/applications/"+  $serverId + "/action-suppressions"
        $name = "ChangeSuppression:" + $env:computername
        $startTime = $dateString
        $endTime = $currentDateTime.AddMinutes(240).ToString("yyyy-MM-ddTHH:mm:ss")
        $serverName = hostname
        
        $serverName
        
        $jsonBody = @{
            "name" = $name
            "disableAgentReporting" = "true"
            "timezone" = "$timezone"
            "startTime" = "$startTime"
            "endTime" = "$endTime"
            "affects" = @{
                "affectedInfoType" = "SERVERS_IN_SERVERS_APP"
                "serversAffectedEntities" = @{
                    "selectServersBy" = "AFFECTED_SERVERS"
                    "affectedServers" = @{
                        "severSelectionScope" = "SERVERS_MATCHING_PATTERN"
                        "patternMatcher" = @{
                            "matchValue" = $serverName
                            "shouldNot" = "false"
                            "matchTo" = "EQUALS"
                        }
        
                    }
                }
            }
            
        } | ConvertTo-Json -Depth 5
        
        
        $credPair = "$($USERNAME):$($PASSWORD)"
        $encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))
        
        
        # Define headers if needed
        $headers = @{
            "Content-Type" = "application/json"
            'Authorization' = "Basic $encodedCredentials"
        }
        
        
        $jsonBody

          # Make the POST request
        if ($proxy) {
            $response = Invoke-RestMethod -Uri $uri -Method Post -Proxy ${proxyHost}:${proxyPort} -Body $jsonBody -Headers $headers
        } else {
            $response = Invoke-RestMethod -Uri $uri -Method Post -Body $jsonBody -Headers $headers
        }
        
        # Output the response
        $response 
 

        
        
    
    } else {
        Write-Host "Service Path: $FilePath"
    }

    


} elseif ($service -ne $null -and $service.Status -ne "Running") {
    Write-Host "The service '$serviceName' is not running."
} else {
    Write-Host "The service '$serviceName' does not exist."
}  


 


  
 
 
