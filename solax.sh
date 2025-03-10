#!/bin/bash

# (c) 2024 Michal Politzer

source $(dirname "$0")/solax.conf
source $(dirname "$0")/solax.login 2>/dev/null

colorDefault="\e[0m"
colorPositive="\e[36m"
colorNegative="\e[31m"
colorDimmed="\e[2m"

# estimate different decimal separator (independent at locale, just test how printf behaves)
decimalseparator=$(echo "$(printf "%1.1f" "3")")
decimalseparator=${decimalseparator:1:1} 


unsignedToSigned() {
  local value=$1
  if ((value > 32767)); then
    value=$((value - 65536))
  fi
  echo "$value"
}

progress_bar() {
  local val=$1
  local max=$2
  local bar_length=20

  # prevent div zero
  [ "$max" -eq "0" ]  && lc_progress=0 || lc_progress=$((val * bar_length / max))  

  local progress_bar=""

  for ((i=0; i<bar_length; i++)); do
    if (( i < lc_progress )); then
      progress_bar+="#"
    else
      progress_bar+="_"
    fi
  done

  echo -n "[$progress_bar]"
}


[[ -z $url ]] && read -p "Invertor URL | IP address: " url ||  url="$url" 
[[ -z $sn ]] && read -p "Invertor Registration No: " sn ||  sn="$sn" 
[[ -z $passwd ]] &&read -p "Invertor passsword: " passwd  ||  passwd="$passwd" 

SerNumCaption=$sn

cat <<EOF > solax.login
url=$url
sn=$sn
passwd=$passwd
EOF


declare -a inverterModeMap
inverterModeMap[0]="Waiting"
inverterModeMap[1]="Checking"
inverterModeMap[2]="Normal"
inverterModeMap[3]="Off"
inverterModeMap[4]="Permanent Fault"
inverterModeMap[5]="Updating"
inverterModeMap[6]="EPS Check"
inverterModeMap[7]="EPS Mode"
inverterModeMap[8]="Self Test"
inverterModeMap[9]="Idle"
inverterModeMap[10]="Standby"

divLine="------------------------------------------------\r"

[[ -z $passwd ]] && sn="$sn" || sn="$passwd"

while true; do

  response=$(curl -m $delay -s -d  "optType=ReadRealTimeData&pwd=$sn" -X POST $url )

  data=$(echo "$response" | jq -r '[.sn,   .Data[14], .Data[15], .Data[82] / 10,  .Data[70] / 10,         .Data[34],  (.Data[93] * 65536 + .Data[92]) / 100, (.Data[91] * 65536 + .Data[90]) / 100, .Data[47], .Data[41],   .Data[79] / 10, .Data[78] / 10, .Data[103], .Data[106] / 10, .Data[105],  .Data[54],   .Data[9],     .Data[19],  .Data[6], .Data[7],  .Data[8]]  | @tsv')
                                read SerNum pv1Power   pv2Power  totalProduction  totalProductionInclBatt feedInPower totalGridIn                            totalGridOut                            load      batteryPower totalChargedIn  totalChargedOut batterySoC   batteryCap       batteryTemp inverterTemp inverterPower inverterMode llph1 llph2 llph3 <<< "$data"

  if [[  $debuglevel = 1  ]]; then
     echo  $response  > last_response.json
     echo  $data      >> last_response.json
  elif [[  $debuglevel > 1  ]]; then
      echo  $response  >> last_response.json
  fi


  totalConsumption=$(echo "$totalGridIn + $totalProductionInclBatt - $totalGridOut" | bc)
  selfSufficiencyRate=$(echo "($totalProductionInclBatt - $totalGridOut) * 100 / $totalConsumption" | bc)

  totalConsumption=${totalConsumption/./$decimalseparator}
  selfSufficiencyRate=${selfSufficiencyRate/./$decimalseparator}

  totalPower=$((pv1Power + pv2Power))
  totalPeak=$((peak1 + peak2))
  feedInPower=$(unsignedToSigned "$feedInPower")
  batteryPower=$(unsignedToSigned "$batteryPower")
  load=$(unsignedToSigned "$load")
  inverterPower=$(unsignedToSigned "$inverterPower")

  
  totalProduction=${totalProduction/./$decimalseparator}
  totalProductionInclBatt=${totalProductionInclBatt/./$decimalseparator}
  totalGridIn=${totalGridIn/./$decimalseparator}
  totalGridOut=${totalGridOut/./$decimalseparator}
  totalChargedIn=${totalChargedIn/./$decimalseparator}
  totalChargedOut=${totalChargedOut/./$decimalseparator}
  batteryCap=${batteryCap/./$decimalseparator}

  clear

  if [[ -z $SerNum  ]] ; then
     printf "\e[0m \e[31mConnection error: $url \e[0m \n"
     printf "$colorDimmed"
     colorDefault=$colorDimmed
     colorPositive=$colorDimmed
     colorNegative=$colorDimmed     
  fi

  echo -e "$divLine"
  dt=$(date) 
  echo $SerNumCaption "      "  $dt
   echo -e "$divLine"
  echo ""
  echo -ne "$divLine"
  echo -e "\033[3C PANELY "
  echo "        celkem: $(printf "%5d" "$totalPower") W   $(progress_bar $totalPower $totalPeak)"
  echo "      string 1: $(printf "%5d" "$pv1Power") W   $(progress_bar $pv1Power $peak1)"
  echo "      string 2: $(printf "%5d" "$pv2Power") W   $(progress_bar $pv2Power $peak2)"
  echo "dnes výroba DC: $(printf "%5.1f" "$totalProduction") kWh"
  echo ""
  echo -ne "$divLine"
  echo -e "\033[3C BATERIE "
  echo "                          $(printf "%3d" "$batterySoC") %        $(printf "%5d" "$batteryTemp") °C"
  echo "        nabití: $(printf "%5.1f" "$batteryCap") kWh $(progress_bar $batterySoC 100)"
  if ((batteryPower >= 0)); then
    printf "      nabíjení: $colorPositive$(printf "%5d" "$batteryPower") W$colorDefault\n"
  else
    printf "      vybíjení: $colorNegative$(printf "%5d" "$batteryPower") W$colorDefault\n"
  fi
  echo "   dnes nabito: $(printf "%5.1f" "$totalChargedIn") kWh"
  echo "        vybito: $(printf "%5.1f" "$totalChargedOut") kWh"
  echo ""
  echo -ne "$divLine"
  echo -e "\033[3C STŘÍDAČ [${inverterModeMap[$inverterMode]}] "
  echo "                                       $(printf "%5d" "$inverterTemp") °C"
  echo "         výkon: $(printf "%5d" "$inverterPower") W   $(progress_bar $inverterPower $maxPower)"
  echo "            L1: $(printf "%5d" "$llph1") W"
  echo "            L2: $(printf "%5d" "$llph2") W"
  echo "            L3: $(printf "%5d" "$llph3") W"
  echo "dnes výroba AC: $(printf "%5.1f" "$totalProductionInclBatt") kWh"
  echo ""
  echo -ne "$divLine"
  echo -e "\033[3C DISTRIBUČNÍ SÍŤ "
  if ((feedInPower < 0)); then
    printf "         odběr: $colorNegative$(printf "%5d" "$feedInPower") W$colorDefault\n"
  else
    printf "       dodávka: $colorPositive$(printf "%5d" "$feedInPower") W$colorDefault\n"
  fi
  echo " dnes odebráno: $(printf "%5.2f" "$totalGridIn") kWh"
  echo "        dodáno: $(printf "%5.2f" "$totalGridOut") kWh"
  echo ""
  echo -ne "$divLine"
  echo -e "\033[3C DŮM "
  echo "aktuální odběr: $(printf "%5d" "$load") W   $(progress_bar $load $maxLoad)"
  echo " dnes spotřeba: $(printf "%5.1f" "$totalConsumption") kWh"
  echo "  soběstačnost:   $(printf "%3d" "$selfSufficiencyRate") %   $(progress_bar $selfSufficiencyRate 100)"
  echo ""

  symbols="/-\|"
  for ((w=0; w<$delay; w++)); do
    for ((i=0; i<${#symbols}; i++)); do
      echo -n "                " "${symbols:$i:1}" " " "$(echo $delay - $w  | bc )" " " "${symbols:$i:1}"  "                    " 
      sleep 0.25
      echo -ne "\r" 
    done
  done
done