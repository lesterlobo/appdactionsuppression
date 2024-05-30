#########################################################################################################
#### Powershell Script to remove action suppress for AppDynamics machine agent alerts for current server
#########################################################################################################


# Initiatize the connection parameters
$controller = ""
$serverId = ""
$USERNAME = ""
$PASSWORD = ""

$Logdir = "c:\zco\logs\"
If (!(Test-Path -Path $Logdir)){New-Item $Logdir -ItemType directory}
$LogfileName = "AppdSuppression"
$Logfile = $Logdir+$LogfileName+".log"
 
Function Write-Log {
   Param ([string]$logstring)
   #replace any nulls with spaces
    $logstring = [regex]::Replace($logstring,[char]0,' ')
 
$timestamp = (Get-Date -format g)
   Add-content $Logfile -value ($timestamp + ": " + $logstring)
}


# Check if AppDynamics Machine Agent is running on this server to trigger action suppression.
$serviceName = "Appdynamics Machine Agent"

# Get the service object
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

# Check if the service object exists and if it's running
if ($service -ne $null) {
    Write-Log "The service '$serviceName' is running."
    # Obtain Machine Agent Install Path
    # Get the service object
    $serviceObject = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"


    Write-Log "Service Path: $($serviceObject.PathName)"

    # Use Split-Path to separate the path into its components
    $FilePath = (Split-Path -Path $($serviceObject.PathName)) + "\MachineAgentService.vmoptions"
    Write-Log "Service Path: $FilePath"

    #$results = Select-String -Path $FilePath -Pattern "appdynamics.controller.hostName" -SimpleMatch
    $results = Get-Content $FilePath | Where-Object {$_ -like "*appdynamics.controller.hostName*"}

    if ($results -ne $null) {

        $controller = $results.split("=")[1]
        Write-Log "Controller Host: $controller"

        $results = Get-Content $FilePath | Where-Object {$_ -like "*appdynamics.agent.accountName*"}
        $accountName = $results.split("=")[1]
        $USERNAME = $USERNAME + "@" + $accountName
        Write-Log "Controller Account: $accountName"

        $proxy = $false

        $results = Get-Content $FilePath | Where-Object {$_ -like "*appdynamics.http.proxyHost*"}
        if ($results -ne $null) {
            $proxyHost = $results.split("=")[1]
            $proxy = $true
            Write-Log "Controller Proxy Host: $proxyHost"
        }
        $results = Get-Content $FilePath | Where-Object {$_ -like "*appdynamics.http.proxyPort*"}
        if ($results -ne $null) {
            $proxyPort = $results.split("=")[1]
            Write-Log "Controller Proxy Port: $proxyPort"
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
        Write-Log "Server ID: $serverId"    
        
        $name = "ChangeSuppression:" + $env:computername

        $uri = "https://"+ $controller + "/controller/alerting/rest/v1/applications/"+  $serverId + "/action-suppressions/action-suppression-by-name/?name=" + $name

        if ($proxy) {
            $response = Invoke-WebRequest -Uri $uri -Method Get -Proxy ${proxyHost}:${proxyPort} -Headers $headers
        } else {
            $response = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers
        }

        $response.StatusCode
        $response.Content
        
        $jsonData = $response.Content | ConvertFrom-Json
    
        $suppressionID = $jsonData.id
        Write-Log "Suppression ID: $suppressionID"   

        $uri = "https://" + $controller + "/controller/alerting/rest/v1/applications/" + $serverId + "/action-suppressions/" + $suppressionID
        

        # Make the Delete request
        

        if ($proxy) {
            $response = Invoke-WebRequest -Uri $uri -Method Delete -Proxy ${proxyHost}:${proxyPort} -Headers $headers -ErrorAction Stop
        } else {
            $response = Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers -ErrorAction Stop
        }
        
        # Output the response
        $response 
 

        
        
    
    } else {
        Write-Log "Service Path: $FilePath"
    }

} else {
    Write-Log "The service '$serviceName' does not exist."
}  
 
