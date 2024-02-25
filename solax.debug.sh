#!/bin/bash

source $(dirname "$0")/solax.conf
source $(dirname "$0")/solax.login 2>/dev/null

while true; do
  response=$(curl -m $delay -s -d  "optType=ReadRealTimeData&pwd=$passwd" -X POST $url )
   data=$(echo "$response" | jq  '[ .Data ]  ')
 
   echo $data >> last_debg_response.json
   sleep 5.00

   echo ...

done   
 