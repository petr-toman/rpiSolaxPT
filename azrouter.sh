unsignedToSigned() {
  local value=$1
  if ((value > 32767)); then
    value=$((value - 65536))
  fi
  echo "$value"
}

# estimate different decimal separator (independent at locale, just test how printf behaves)
decimalseparator=$(echo "$(printf "%1.1f" "3")")
decimalseparator=${decimalseparator:1:1} 



urlazrouter=http://azrouter.local/api/v1/power
urlazrouterdevices=http://azrouter.local/api/v1/devices


while true; do


response=$(curl  -s $urlazrouter )

  data=$(echo "$response" | jq -r  '[.input.current[0].value, 
                                     .input.current[1].value, 
                                     .input.current[2].value, 
                                     .input.power[0].value, 
                                     .input.power[1].value, 
                                     .input.power[2].value,
                                     .output.energy[0].value, 
                                     .output.energy[1].value, 
                                     .output.energy[2].value
                                     ]| @tsv')
read CurrL1 CurrL2 CurrL3 PowerL1 PowerL2 PowerL3 EnergyL1 EnergyL2 EnergyL3  <<< "$data"
echo  $response  > az.last_response.json
clear
  echo "------------------------------------------------"
  dt=$(date) 
  echo  $urlazrouter "      "  $dt
  echo "------------------------------------------------"
  echo ""

CurrL1=${CurrL1/./$decimalseparator}
CurrL2=${CurrL2/./$decimalseparator}
CurrL3=${CurrL3/./$decimalseparator}


echo "Current: "

if (( CurrL1 >= 0 )); then
    printf "L1     přetok: \e[36m$(printf "%5.1f" $CurrL1 )  A\e[0m\n"
  else
    printf "L1     dokup: \e[31m$(printf "%5.1f"  $CurrL1 )  A\e[0m\n"
fi
if (( CurrL2 >= 0)); then
    printf "L2     přetok: \e[36m$(printf "%5.1f" $CurrL2 ) A\e[0m\n"
  else
    printf "L2     dokup: \e[31m$(printf "%5.1f" $CurrL2 )  A\e[0m\n"
fi
if (( CurrL3 >= 0)); then
    printf "L3    přetok: \e[36m$(printf "%5.1f" $CurrL3 ) A\e[0m\n"
  else
    printf "L3     dokup: \e[31m$(printf "%5.1f" $CurrL3 )  A\e[0m\n"
fi


echo "Power: "

if (( PowerL1 >= 0 )); then
    
    printf "L1     přetok: \e[36m$(printf "%5.1f" $PowerL1 )  W\e[0m\n"
  else
    printf "L1     dokup: \e[31m$(printf "%5.1f"  $PowerL1 )  W\e[0m\n"
fi
if (( PowerL2 >= 0)); then
    printf "L2     přetok: \e[36m$(printf "%5.1f" $PowerL2 ) W\e[0m\n"
  else
    printf "L2     dokup: \e[31m$(printf "%5.1f" $PowerL2 )  W\e[0m\n"
fi
if (( PowerL3 >= 0)); then
    printf "L3    přetok: \e[36m$(printf "%5.1f" $PowerL3 ) W\e[0m\n"
  else
    printf "L3     dokup: \e[31m$(printf "%5.1f" $PowerL3 )  W\e[0m\n"
fi

echo "Energy Consumption: "
echo  $EnergyL1
 printf "L1  spotřeba: \e[31m$(printf "%5.1f"  $EnergyL1 )  W\e[0m\n"
 printf "L2  spotřeba: \e[31m$(printf "%5.1f"  $EnergyL2 )  W\e[0m\n"
 printf "L3  spotřeba: \e[31m$(printf "%5.1f"  $EnergyL3 )  W\e[0m\n"


done