#!/bin/bash

name=''
servers=''
startTime=''
endTime=''
days=''
suppressionScheduleType=''
scheduleFrequency=''
startTimeSchedule=''
endTimeSchedule=''
recurringData=''


generate_post_data()
{
cat <<-END  
    {
        "name": "${name}", 
        "disableAgentReporting": false, 
        "suppressionScheduleType": "${suppressionScheduleType}",
        "startTime": "${startTime}",
        "endTime": "${endTime}",
        "recurringSchedule": ${recurringData},
        "affects": {
            "affectedInfoType": "SERVERS_IN_SERVERS_APP",
            "serversAffectedEntities": {
                "selectServersBy": "AFFECTED_SERVERS",
                "affectedServers": {
                    "severSelectionScope": "SPECIFIC_SERVERS",
                    "servers": ${servers}
                }
            }
        },
        "healthRuleScope": null
    }
END
}

generateRecurringData()
{
cat <<-END 
    {
        "scheduleFrequency": "${scheduleFrequency}",
        "startTime": "${startTimeSchedule}",
        "endTime": "${endTimeSchedule}",
        "days": ${days}
    }
END
}

echo -e "---Type your SaaS Controller URL example [https://demo.saas.appdyanamics.com]---\n[Careful, do not include anything after the .com]"
read URL
echo -e "---This is your URL: $URL---"
echo -e "---Type your account name (The one you use to log in your Multi-tenant Controller)---\n[If you use a Single Tenant Controller then type: customer1]"
read ACCOUNT
echo -e "---Account Name: $ACCOUNT----"
echo -e "---Type your Username or Email ID (The one you use to log to your controller)---\n[This user MUST BE LOCAL USER]\n[NOTE if you input your email, please ESCAPE the @ sign with %40 Example: [demo1@gmail.com -> demo1%40gmail.com]]"
read USERNAME
echo -e "---Username: $USERNAME---"
echo -e "---Type the password for that User---"
read PASSWORD

echo -e "---Type the name of the new Action Supression---"
read name
echo -e "---Action Supression Name: $name---"
echo -e "-Type 1 if RECURRENT or 2 if ON_TIME--"
read RECURRENT_TYPE
if [ $RECURRENT_TYPE == 1 ]; then
    suppressionScheduleType="RECURRING"
    startTime=null
    endTime=null
    echo -e "---Type the Schedule Frequency: 1 for DAILY, 2 for WEEKLY, 3 for MONTHLY---"
    read SCHEDULE_TYPE 
    if [ $SCHEDULE_TYPE == 1 ]; then
        scheduleFrequency="DAILY"
        echo -e "---Scheduling Frequency: $scheduleFrequency---"
        echo -e "---Type the the time at which the action suppression is initiated. The time in 24 hour format. Example: 18:00---"
        read startTimeSchedule 
        echo -e "---Start Time of Recurring Action Supression: $startTimeSchedule---"
        echo -e "---Type the the time at which the action suppression is terminated. The time in 24 hour format. Example: 19:00---"
        read endTimeSchedule 
        echo -e "---End Time of Recurring Action Supression: $endTimeSchedule---"
        days="[]"
    elif [ $SCHEDULE_TYPE == 2 ]; then 
        scheduleFrequency="WEEKLY"
        echo -e "---Scheduling Frequency: $scheduleFrequency---"
         echo -e "---Type the the time at which the action suppression is initiated. The time in 24 hour format. Example: 18:00---"
        read startTimeSchedule 
        echo -e "---Start Time of Recurring Action Supression: $startTimeSchedule---"
        echo -e "---Type the the time at which the action suppression is terminated. The time in 24 hour format. Example: 19:00---"
        read endTimeSchedule 
        echo -e "---End Time of Recurring Action Supression: $endTimeSchedule---"
        echo -e "---Type the days of the weeks that this is going to be active separated by commas---"
        echo -e "---[1: Monday, 2: Tuesday, 3: Wednesday, 4: Thursday, 5: Friday, 6: Saturday, 7: Sunday]---"
        echo -e "---Example: 1,3 (Monday and Wednesday)---"
        read daysActive 
        IFS=', ' read -r -a array_days <<< "$daysActive"
        arrayOfDays=()
        for element in "${array_days[@]}"
        do
            echo "$element"
            if [ $element == 1 ]; then 
                arrayOfDays+=("MONDAY")
            elif [ $element == 2 ]; then 
                arrayOfDays+=("TUESDAY")
            elif [ $element == 3 ]; then 
                arrayOfDays+=("WEDNESDAY")
            elif [ $element == 4 ]; then 
                arrayOfDays+=("THURSDAY")
            elif [ $element == 5 ]; then 
                arrayOfDays+=("FRIDAY")
            elif [ $element == 6 ]; then 
                arrayOfDays+=("SATURDAY")
            elif [ $element == 7 ]; then 
                arrayOfDays+=("SUNDAY")
            fi
        done
        jo -a "${arrayOfDays[@]}"
        days+="$(jo -a "${arrayOfDays[@]}")"
    elif [ $SCHEDULE_TYPE == 3 ]; then
        scheduleFrequency="MONTHLY"
        echo -e "Scheduling Frequency: $scheduleFrequency"
    fi
    recurringData=$(generateRecurringData)
    echo "$recurringData"
elif [ $RECURRENT_TYPE == 2 ]; then
    suppressionScheduleType="ONE_TIME"
    echo -e "Recurring Type: $suppressionScheduleType"
    echo -e "--Type the Start DateTime of the ONE_TIME Action Supression Use FORMAT[YYYY-MM-DDThh:mm:ss] Example: 2020-06-18T13:33:37--"
    read startTime
    echo -e "Start Time Action Supression: $startTime"
    echo -e "--Type the End DateTime of the ONE_TIME Action Supression. Use FORMAT[YYYY-MM-DDThh:mm:ss] Example: 2020-06-18T15:33:37--"
    read endTime
    echo -e "End Time Action Supression: $endTime"
    recurringData="null"
fi



echo -e "----CREATING ACTION SUPRESSION-----"
response=$(curl --user "$USERNAME@$ACCOUNT:$PASSWORD" "$URL/controller/rest/applications/Server%20%26%20Infrastructure%20Monitoring")
filtered=$(echo $response | xmlstarlet sel -T -t -m '/applications/application/id' -v '.' -n)
eval "array=($filtered)"
for element in "${array[@]}"; do
    echo $element
    my_array=()
    array_days=()
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [ $line !=  "Host Name" ]; then
            echo "$line"
            string1=$(echo "$line")
            response3=$(curl --user "$USERNAME@$ACCOUNT:$PASSWORD" "$URL/controller/rest/applications/$element/nodes/$line")
            filtered3=$(echo $response3 | xmlstarlet sel -T -t -m '/nodes/node/id' -v '.' -n)
            eval "array_node=($filtered3)"
            my_array+=("${array_node[0]}")
        fi
    done < "$1"
    servers+="$(jo -a "${my_array[@]}")"
    echo $servers
    echo -e "PAYLOAD: $(generate_post_data)"
    response2=$(curl -X POST --user "$USERNAME@$ACCOUNT:$PASSWORD" -H 'Content-Type: application/json' "$URL/controller/alerting/rest/v1/applications/$element/action-suppressions" --data "$(generate_post_data)")
    echo $response2
done 

echo -e "----ACTION SUPRESSION CREATED SUCCESSFULLY-----"
exit 0
