#!/bin/bash

source "$(dirname "$0")/solax.conf" 2>/dev/null
# Konfigurace FVE: Pokud něco chybí, doptej se nebo nastav výchozí hodnoty a ulož soubor
if [[ ! -f "solax.conf" || -z "$peak1" || -z "$peak2" || -z "$maxPower" || -z "$maxLoad" || -z "$delay" || -z "$debuglevel" ]]; then
  [[ -z $peak1 ]]      && read -p "Peak String 1 panel power (W): " peak1
  [[ -z $peak2 ]]      && read -p "Peak String 2 panel power (W): " peak2
  [[ -z $maxPower ]]   && read -p "Max inverter power (W): " maxPower
  [[ -z $maxLoad ]]    && read -p "Max house load i.e. 3 x 25A x 230V = 17250 (W): " maxLoad
  [[ -z $delay ]]      && read -p "Refresh read delay (s): " delay
  [[ -z $debuglevel ]] && read -p "Debug level (0: none, 1: last call only, 2: cumulated): " debuglevel

  printf '%s\n' \
    "peak1=${peak1:-4500}" \
    "peak2=${peak2:-0}" \
    "maxPower=${maxPower:-4500}" \
    "maxLoad=${maxLoad:-16000}" \
    "delay=${delay:-4}" \
    "debuglevel=${debuglevel:-2}" \
    > "solax.conf"
  chmod 644 "solax.conf"
fi


source $(dirname "$0")/solax.login 2>/dev/null
# login file: je tam url solaxu a heslo..., když neexistuje, zeptá se a vytvoří
if [[ ! -f "solax.login" || -z "$url" || -z "$passwd" ]]; then
[[ -z $url ]] && read -p "Invertor URL | IP address: " url ||  url="$url" 
[[ -z $passwd ]] &&read -p "Invertor passsword: " passwd  ||  passwd="$passwd" 
  printf '%s\n' "url=$url" "passwd=$passwd" > "solax.login"
  chmod 600 "solax.login"
fi

colorDefault="\e[0m"
colorPositive="\e[36m"
colorNegative="\e[31m"
colorDimmed="\e[2m"

# estimate different decimal separator (independent at locale, just test how printf behaves)
decimalseparator=$(echo "$(printf "%1.1f" "3")")
decimalseparator=${decimalseparator:1:1} 



         
# Vytvoří JSON objekt dle mappingu a vypíše ho na stdout
build_status_json() {
  echo "$response" | jq -r \
    --argjson peak1 "${peak1:-0}" \
    --argjson peak2 "${peak2:-0}" '
    # parametrické funkce
    def s16(x): if (x // 0) >= 32768 then (x // 0) - 65536 else (x // 0) end;
    def u32(a; b): ((a // 0) * 65536) + (b // 0);
    def s32(a; b): (((a // 0) * 65536 + (b // 0)) as $v
                    | if $v >= 2147483648 then $v - 4294967296 else $v end);

    # 1) základní objekt jako $o
    (
      {
        SerNum:                  (.sn // null),
        PowerDc1:                (.Data[14] // 0),
        PowerDc2:                (.Data[15] // 0),
        totalProduction:         ((.Data[82] // 0) / 10),   # kWh (DC today)
        Yield_Today:             ((.Data[70] // 0) / 10),   # kWh (AC today)
        feedInPower:             s16(.Data[34] // 0),
        _feedInPower:            s32(.Data[34] // 0; .Data[35] // 0),
        totalGridIn:             (u32(.Data[93] // 0; .Data[92] // 0) / 100),
        totalGridOut:            (u32(.Data[91] // 0; .Data[90] // 0) / 100),
        load:                    s16(.Data[47] // 0),
        batteryPower:            s16(.Data[41] // 0),
        totalChargedIn:          ((.Data[79] // 0) / 10),
        totalChargedOut:         ((.Data[78] // 0) / 10),
        batterySoC:              (.Data[103] // 0),
        batteryCapacitykWh:      ((.Data[106] // 0) / 10),
        batteryTemp:             (.Data[105] // 0),
        inverterTemp:            (.Data[54] // 0),
        inverterPower:           s16(.Data[9] // 0),
        inverterMode:            (.Data[19] // 0),
        GridL1Power:               s16(.Data[6] // 0),
        GridL2Power:               s16(.Data[7] // 0),
        GridL3Power:               s16(.Data[8] // 0),
        _Yield_Total:             (u32(.Data[68] // 0; .Data[69] // 0) / 10),
        _FeedInEnergy:            (u32(.Data[86] // 0; .Data[87] // 0) / 100),
        _ConsumeEnergy:           (u32(.Data[88] // 0; .Data[89] // 0) / 100),
        _EPSAPower:               s16(.Data[29] // 0),
        _EPSBPower:               s16(.Data[30] // 0),
        _EPSCPower:               s16(.Data[31] // 0),
        _Vdc1:                    ((.Data[10] // 0) / 10),
        _Vdc2:                    ((.Data[11] // 0) / 10),
        _Idc1:                    ((.Data[12] // 0) / 10),
        _Idc2:                    ((.Data[13] // 0) / 10),
        _EPSAVoltage:             ((.Data[23] // 0) / 10),
        _EPSBVoltage:             ((.Data[24] // 0) / 10),
        _EPSCVoltage:             ((.Data[25] // 0) / 10),
        _EPSACurrent:             (s16(.Data[26] // 0) / 10),
        _EPSBCurrent:             (s16(.Data[27] // 0) / 10),
        _EPSCCurrent:             (s16(.Data[28] // 0) / 10),
        _BatteryVoltage:          (u32(.Data[169] // 0; .Data[170] // 0) / 100),
        _GridL1Voltage:            ((.Data[0] // 0) / 10),
        _GridL2Voltage:            ((.Data[1] // 0) / 10),
        _GridL3Voltage:            ((.Data[2] // 0) / 10),
        _GridL1Current:            (s16(.Data[3] // 0) / 10),
        _GridL2Current:            (s16(.Data[4] // 0) / 10),
        _GridL3Current:            (s16(.Data[5] // 0) / 10),
        _FreqacA:                 ((.Data[16] // 0) / 100),
        _FreqacB:                 ((.Data[17] // 0) / 100),
        _FreqacC:                 ((.Data[18] // 0) / 100)
      } as $o
      # 2) dopočty z již hotového $o
      | $o + {
          totalConsumption:      (($o.totalGridIn // 0)
                                  + ($o.Yield_Today // 0)
                                  - ($o.totalGridOut // 0)),
          selfSufficiencyRate:   ( if (($o.totalGridIn // 0)
                                        + ($o.Yield_Today // 0)
                                        - ($o.totalGridOut // 0)) == 0
                                   then 0
                                   else (
                                     (($o.Yield_Today // 0)
                                      - ($o.totalGridOut // 0)) * 100
                                     /
                                     (($o.totalGridIn // 0)
                                      + ($o.Yield_Today // 0)
                                      - ($o.totalGridOut // 0))
                                   )
                                   end ),
          PowerDCtotal:            (($o.PowerDc1 // 0) + ($o.PowerDc2 // 0)),
          totalPeak:             (($peak1 // 0) + ($peak2 // 0))
        }
    )
  ' 2>&1
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

while true; do

  response=$(curl -m $delay -s -d  "optType=ReadRealTimeData&pwd=$passwd" -X POST $url )

  data=$(echo "$response" | jq -r '
       def s16(x): if x >= 32768 then x - 65536 else x end;
  [
   .sn,                                    # SerNum
   .Data[14],                              # PowerDc1  (W)
   .Data[15],                              # PowerDc2  (W)
   .Data[82] / 10,                         # totalProduction (DC today, kWh)
   .Data[70] / 10,                         # Yield_Today (AC today, kWh)
   (s16(.Data[34])),                       # feedInPower 
   (.Data[93] * 65536 + .Data[92]) / 100,  # totalGridIn  (kWh)
   (.Data[91] * 65536 + .Data[90]) / 100,  # totalGridOut (kWh)
   (s16(.Data[47])),                       # load (W)
   (s16(.Data[41])),                       # batteryPower (W)
   .Data[79] / 10,                         # totalChargedIn (kWh)
   .Data[78] / 10,                         # totalChargedOut (kWh)
   .Data[103],                             # batterySoC (%)
   .Data[106] / 10,                        # batteryCapacitykWh (kWh today)
   .Data[105],                             # batteryTemp (°C)
   .Data[54],                              # inverterTemp (°C)
   (s16(.Data[9])),                        # inverterPower (W)
   .Data[19],                              # inverterMode (enum)
   .Data[6], .Data[7], .Data[8]            # GridL1Power/GridL2Power/GridL3Power (W, per-phase)
  ] | @tsv' )     # neboli řada hodnot oddělená tabuláterom, které pak read načte do jednotlivých env proměnných
  
read SerNum \
     PowerDc1 \
     PowerDc2 \
     totalProduction \
     Yield_Today \
     feedInPower \
     totalGridIn \
     totalGridOut \
     load \
     batteryPower \
     totalChargedIn \
     totalChargedOut \
     batterySoC \
     batteryCapacitykWh \
     batteryTemp \
     inverterTemp \
     inverterPower \
     inverterMode \
     GridL1Power GridL2Power GridL3Power  <<< "$data"  


  totalConsumption=$(echo "$totalGridIn + $Yield_Today - $totalGridOut" | bc)
  selfSufficiencyRate=$(echo "($Yield_Today - $totalGridOut) * 100 / $totalConsumption" | bc)
  PowerDCtotal=$((PowerDc1 + PowerDc2))
  totalPeak=$((peak1 + peak2))


  totalConsumption=${totalConsumption/./$decimalseparator}
  selfSufficiencyRate=${selfSufficiencyRate/./$decimalseparator}
  totalProduction=${totalProduction/./$decimalseparator}
  Yield_Today=${Yield_Today/./$decimalseparator}
  totalGridIn=${totalGridIn/./$decimalseparator}
  totalGridOut=${totalGridOut/./$decimalseparator}
  totalChargedIn=${totalChargedIn/./$decimalseparator}
  totalChargedOut=${totalChargedOut/./$decimalseparator}
  batteryCapacitykWh=${batteryCapacitykWh/./$decimalseparator}


  if [[  $debuglevel = 1  ]]; then
     echo  $response  > log/last_response.json
     build_status_json > log/build_status_json.json
     echo "["$data"]"      > log/data.json
  elif [[  $debuglevel > 1  ]]; then
     echo  $response  >> log/last_response.json
     build_status_json >> log/build_status_json.json
     echo  $data      >> log/data.json
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
  echo $SerNum "      "  $dt
   echo -e "$divLine"
  echo ""
##################################################################################################################  
  echo -ne "$divLine"
  echo -e "\033[3C PANELY "
  echo "        celkem: $(printf "%5d" "$PowerDCtotal") W   $(progress_bar $PowerDCtotal $totalPeak)"
  echo "      string 1: $(printf "%5d" "$PowerDc1") W   $(progress_bar $PowerDc1 $peak1)"
  echo "      string 2: $(printf "%5d" "$PowerDc2") W   $(progress_bar $PowerDc2 $peak2)"
  echo "dnes výroba DC: $(printf "%5.1f" "$totalProduction") kWh"
  echo ""
##################################################################################################################  
  echo -ne "$divLine"
  echo -e "\033[3C BATERIE "
  echo "                          $(printf "%3d" "$batterySoC") %        $(printf "%5d" "$batteryTemp") °C"
  echo "        nabití: $(printf "%5.1f" "$batteryCapacitykWh") kWh $(progress_bar $batterySoC 100)"
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
  echo "            L1: $(printf "%5d" "$GridL1Power") W"
  echo "            L2: $(printf "%5d" "$GridL2Power") W"
  echo "            L3: $(printf "%5d" "$GridL3Power") W"
  echo "dnes výroba AC: $(printf "%5.1f" "$Yield_Today") kWh"
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