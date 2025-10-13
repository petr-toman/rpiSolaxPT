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


# Vytvoří JSON objekt dle mappingu a vypíše ho na stdout
build_status_json() {
  echo "$response" | jq -r '
    # pomocné funkce bez parametrů (kompatibilní se starším jq)
    def s16:  if . >= 32768 then . - 65536 else . end;
    def u32:  .[0]*65536 + .[1];
    def s32:  ((.[0]*65536 + .[1]) as $v | if $v >= 2147483648 then $v - 4294967296 else $v end);

    {
      Yield_Today:          (.Data[70] / 10),
      Yield_Total:          ([.Data[68], .Data[69]] | u32 / 10),
      PowerDc1:             .Data[14],
      PowerDc2:             .Data[15],
      BAT_Power:            (.Data[41] | s16),
      feedInPower:          ([.Data[34], .Data[35]] | s32),
      GridAPower:           (.Data[6]  | s16),
      GridBPower:           (.Data[7]  | s16),
      GridCPower:           (.Data[8]  | s16),
      FeedInEnergy:         ([.Data[86], .Data[87]] | u32 / 100),
      ConsumeEnergy:        ([.Data[88], .Data[89]] | u32 / 100),
      RunMode:              .Data[19],
      EPSAPower:            (.Data[29] | s16),
      EPSBPower:            (.Data[30] | s16),
      EPSCPower:            (.Data[31] | s16),
      Vdc1:                 (.Data[10] / 10),
      Vdc2:                 (.Data[11] / 10),
      Idc1:                 (.Data[12] / 10),
      Idc2:                 (.Data[13] / 10),
      EPSAVoltage:          (.Data[23] / 10),
      EPSBVoltage:          (.Data[24] / 10),
      EPSCVoltage:          (.Data[25] / 10),
      EPSACurrent:          (.Data[26] | s16 / 10),
      EPSBCurrent:          (.Data[27] | s16 / 10),
      EPSCCurrent:          (.Data[28] | s16 / 10),
      BatteryCapacity:      .Data[103],
      BatteryVoltage:       ([.Data[169], .Data[170]] | u32 / 100),
      BatteryTemperature:   (.Data[105] | s16),
      GridAVoltage:         (.Data[0] / 10),
      GridBVoltage:         (.Data[1] / 10),
      GridCVoltage:         (.Data[2] / 10),
      GridACurrent:         (.Data[3] | s16 / 10),
      GridBCurrent:         (.Data[4] | s16 / 10),
      GridCCurrent:         (.Data[5] | s16 / 10),
      FreqacA:              (.Data[16] / 100),
      FreqacB:              (.Data[17] / 100),
      FreqacC:              (.Data[18] / 100),
       SerNum:               .sn,
      totalProduction:      (.Data[82] / 10),
      totalGridIn:          ([.Data[93], .Data[92]] | u32 / 100),
      totalGridOut:         ([.Data[91], .Data[90]] | u32 / 100),
      load:                 .Data[47],
      totalChargedIn:       (.Data[79] / 10),
      totalChargedOut:      (.Data[78] / 10),
      batteryCap:           (.Data[106] / 10),
      inverterTemp:         .Data[54],
      inverterPower:        .Data[9]
    }'
}


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

  data=$(echo "$response" | jq -r '
       def s16(x): if x >= 32768 then x - 65536 else x end;
       def s32(hi; lo):
            ((hi * 65536) + lo) as $v
           | if $v >= 2147483648 then $v - 4294967296 else $v end;

  [
   .sn, #SerNum
   .Data[14],                        # pv1Power  (W)
   .Data[15],                        # pv2Power  (W)
   .Data[82] / 10,                   # totalProduction (DC today, kWh)
   .Data[70] / 10,                   # totalProductionInclBatt (AC today, kWh)
   (s16(.Data[34])),                 # feedInPower 
   (.Data[93] * 65536 + .Data[92]) / 100,  # totalGridIn  (kWh)
   (.Data[91] * 65536 + .Data[90]) / 100,  # totalGridOut (kWh)
   (s16(.Data[47])),                 # load (W)
   (s16(.Data[41])),                 # batteryPower (W)
   .Data[79] / 10,                   # totalChargedIn (kWh)
   .Data[78] / 10,                   # totalChargedOut (kWh)
   .Data[103],                       # batterySoC (%)
   .Data[106] / 10,                  # batteryCap (kWh today)
   .Data[105],                       # batteryTemp (°C)
   .Data[54],                        # inverterTemp (°C)
   (s16(.Data[9])),                  # inverterPower (W)
   .Data[19],                        # inverterMode (enum)
   .Data[6], .Data[7], .Data[8],      # llph1/llph2/llph3 (W, per-phase)
   ((.Data[93]*65536 + .Data[92]) / 100 + (.Data[70]/10) - ((.Data[91]*65536 + .Data[90]) / 100)) # dopočet: totalConsumption = totalGridIn + totalProductionInclBatt - totalGridOut

  ] | @tsv' )     # neboli řada hodnot oddělená tabuláterom, které pak read načte do jednotlivých env proměnných
  
read SerNum \
     pv1Power \
     pv2Power \
     totalProduction \
     totalProductionInclBatt \
     feedInPower \
     totalGridIn \
     totalGridOut \
     load \
     batteryPower \
     totalChargedIn \
     totalChargedOut \
     batterySoC \
     batteryCap \
     batteryTemp \
     inverterTemp \
     inverterPower \
     inverterMode \
     llph1 llph2 llph3 \
     totalConsumption  <<< "$data"  


  #feedInPower=$(unsignedToSigned "$feedInPower")
  #batteryPower=$(unsignedToSigned "$batteryPower")
  #load=$(unsignedToSigned "$load")
  #inverterPower=$(unsignedToSigned "$inverterPower")
  #ftotalConsumption=$(echo "$totalGridIn + $totalProductionInclBatt - $totalGridOut" | bc)
  selfSufficiencyRate=$(echo "($totalProductionInclBatt - $totalGridOut) * 100 / $totalConsumption" | bc)
  totalPower=$((pv1Power + pv2Power))
  totalPeak=$((peak1 + peak2))

  totalConsumption=${totalConsumption/./$decimalseparator}
  selfSufficiencyRate=${selfSufficiencyRate/./$decimalseparator}

  totalProduction=${totalProduction/./$decimalseparator}
  totalProductionInclBatt=${totalProductionInclBatt/./$decimalseparator}
  totalGridIn=${totalGridIn/./$decimalseparator}
  totalGridOut=${totalGridOut/./$decimalseparator}
  totalChargedIn=${totalChargedIn/./$decimalseparator}
  totalChargedOut=${totalChargedOut/./$decimalseparator}
  batteryCap=${batteryCap/./$decimalseparator}


  if [[  $debuglevel = 1  ]]; then
     echo  $response  >> log/last_response.json
     build_status_json >> log/build_status_json.json
     echo  $data      >> log/data.json


  elif [[  $debuglevel > 1  ]]; then
      echo  $response  >> last_response.json
  fi


##################################################################################################################
#máme načteno a upraveno, jdeme s tím na obrazovku:
##################################################################################################################

  clear

  if [[ -z $SerNum  ]] ; then
     printf "\e[0m \e[31mConnection error: $url \e[0m \n"
     printf "$colorDimmed"
     colorDefault=$colorDimmed
     colorPositive=$colorDimmed
     colorNegative=$colorDimmed     
  fi
##################################################################################################################
  echo -e "$divLine"
  dt=$(date) 
  echo $SerNumCaption "      "  $dt
   echo -e "$divLine"
  echo ""
##################################################################################################################  
  echo -ne "$divLine"
  echo -e "\033[3C PANELY "
  echo "        celkem: $(printf "%5d" "$totalPower") W   $(progress_bar $totalPower $totalPeak)"
  echo "      string 1: $(printf "%5d" "$pv1Power") W   $(progress_bar $pv1Power $peak1)"
  echo "      string 2: $(printf "%5d" "$pv2Power") W   $(progress_bar $pv2Power $peak2)"
  echo "dnes výroba DC: $(printf "%5.1f" "$totalProduction") kWh"
  echo ""
##################################################################################################################  
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
##################################################################################################################  
  echo -ne "$divLine"
  echo -e "\033[3C STŘÍDAČ [${inverterModeMap[$inverterMode]}] "
  echo "                                       $(printf "%5d" "$inverterTemp") °C"
  echo "         výkon: $(printf "%5d" "$inverterPower") W   $(progress_bar $inverterPower $maxPower)"
  echo "            L1: $(printf "%5d" "$llph1") W"
  echo "            L2: $(printf "%5d" "$llph2") W"
  echo "            L3: $(printf "%5d" "$llph3") W"
  echo "dnes výroba AC: $(printf "%5.1f" "$totalProductionInclBatt") kWh"
  echo ""
##################################################################################################################  
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
##################################################################################################################
  symbols="/-\|"
  for ((w=0; w<$delay; w++)); do
    for ((i=0; i<${#symbols}; i++)); do
      echo -n "                " "${symbols:$i:1}" " " "$(echo $delay - $w  | bc )" " " "${symbols:$i:1}"  "                    " 
      sleep 0.25
      echo -ne "\r" 
    done
  done
done
##################################################################################################################