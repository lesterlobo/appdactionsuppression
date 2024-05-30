 # Define the endpoint URL
 $uri = "<controller url>/alerting/rest/v1/applications/<sim app id>/action-suppressions"
 $USERNAME = ""
 $PASSWORD = ""
 # Get the current date and time
 $currentDateTime = Get-Date
 
 # Format the date
 $dateString = $currentDateTime.ToString("yyyy-MM-ddTHH:mm:ss")
 
 
 $name = "ChangeSuppression:" + $env:computername
 $startTime = $dateString
 $endTime = $currentDateTime.AddMinutes(60).ToString("yyyy-MM-ddTHH:mm:ss")
 $serverName = hostname
 
 $serverName
 
 $jsonBody = @{
     "name" = $name
     "disableAgentReporting" = "true"
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
 $response = Invoke-RestMethod -Uri $uri -Method Post -Body $jsonBody -Headers $headers
 
 # Output the response
 $response 
 
