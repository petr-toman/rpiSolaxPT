Bash script for Raspberry Pi command line for online monitor Solax inverter

## Instalation
- download to any directory (f.e. ~/rpiSolax)
- set solax.sh as executable (chmod 0775 solax.sh)
- install command line JSON parser 'jq' if missing (sudo apt install jq)
- edit solax.conf (use your Solax Inverter serial number, your local IP address, optionally inverter password(if differs from Inverter SN) set string 1 and string 2 maximum power (kWp), set delay between refresh (default is 4 seconds)
-alternatively: let the script prompt you for url, SN and pass and store it in solax.login file for next use


## Usage
- enter yourDirectory/solax.sh (f.e. ~/rpiSolax/solax.sh)
- press Ctrl + C to end script
