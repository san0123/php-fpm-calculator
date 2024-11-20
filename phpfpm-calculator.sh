#!/usr/bin/env bash
################################################################
# php-fpm pool calculater.
#   ex~]# ./phpfpm-calculator.sh 3
#         ./phpfpm-calculator.sh [number of site]
#
#                     2024-11-20 by Enteroa(enteroa.j@gmail.com)
################################################################
function PssCheck {
  local x=0
  for a in $(ps --no-headers -o pid -C $PROCESS)
    do x=$(expr $x + $(cat /proc/$a/smaps | awk '/Pss/{x+=$2}END{print x}'));done
  CONSUME=$x
}
MEMINFO=$(free -k | grep ^Mem:)
RAMTOTAL=$(echo $MEMINFO | cut -d" " -f2)
RAMUSED=$(echo $MEMINFO | cut -d" " -f3)
RAMBUFF=$(echo $MEMINFO | cut -d" " -f6)
RAMFREE=$(echo $MEMINFO | cut -d" " -f4)
TearOff="\e[31;1m-----------------------------------------\e[0m"
echo -e $TearOff
printf "%-9s %-7s %-7s %-7s %-7s\n" "" "TOTAL" "USED" "BUFF" "FREE"
echo -e $TearOff
printf "%-9s %-7s %-7s %-7s %-7s\n" "MEMORY" "$(awk '{printf "%0.0f", $1/1024}' <<< $RAMTOTAL)M" "$(awk '{printf "%0.0f", $1/1024}' <<< $RAMUSED)M" "$(awk '{printf "%0.0f", $1/1024}' <<< $RAMBUFF)M" "$(awk '{printf "%0.0f", $1/1024}' <<< $RAMFREE)M"
echo -e $TearOff
for b in nginx httpd apache2 mariadbd mysqld php-fpm
  do
  PROCESS=$(ps --no-headers -o command xc | grep $b | uniq)
  if [[ ! -z $PROCESS ]];then
    PssCheck
    echo "$PROCESS used $(awk '{printf "%0.1f", $1/1024}' <<< $CONSUME)MB"
    if [[ $b == "php-fpm" ]];then PHPMEM=$CONSUME;fi
  fi
  done
echo -e $TearOff
if [[ -n $1 ]];then if [[ $1 -eq 0 ]];then DEVIDE=1;else DEVIDE=$1;fi;else DEVIDE=1;fi
if [[ -z $PHPMEM ]];then PHPMEM=0;fi
USETO=$(awk '{print int(($1+$2+$3-($4/10))/$5)}' <<< "$RAMFREE $RAMBUFF $PHPMEM $RAMTOTAL $DEVIDE")
echo -n "FreeMemory($(awk '{printf "%0.1f", $1/1024/1024}' <<< $RAMFREE)G) + "
echo -n "Buffer($(awk '{printf "%0.1f", $1/1024/1024}' <<< $RAMBUFF)G) + "
echo -n "PHP_Consume($(awk '{printf "%0.1f", $1/1024/1024}' <<< $PHPMEM)G) - "
echo -n "Memory_10%($(awk '{printf "%0.1f", $1/10/1024/1024}' <<< $RAMTOTAL)G) = "
echo "$(awk '{printf "%0.1f", ($1+$2+$3-($4/10))/1024/1024}' <<< "$RAMFREE $RAMBUFF $PHPMEM $RAMTOTAL")G"
echo -e $TearOff
PROCESS=$(ps --no-headers -o command xc | grep php-fpm | uniq)
CHILD=$(ps --no-headers --sort -size -o size,command -C $PROCESS | \
          awk '!/master process/{x+=$1;l+=1}END{print int(x/l)}' 2>/dev/null)
if [[ -z $CHILD ]];then
  CHILD=19087
  echo there are php-fpm process non exist. so child set use 18.6M fixed.
else
  ps --no-headers --sort -size -o size,command -C $PROCESS | \
     awk '{printf("%0.2f MB ", $1/1024)}{for(x=2;x<=NF;x++){printf("%s ", $x)}print ""}'
fi
echo -e "\e[32;1mphp-fpm child average memory usage $(awk '{printf "%0.1f", $1/1024}' <<< $CHILD)M\e[0m"
echo -e $TearOff
echo "$DEVIDE site use to $(awk '{printf "%0.1f", $1/1024}' <<< $USETO)M memory per each."
echo -e $TearOff
PER_MEMORY=$(awk '{print int($1/$2/1024)}' <<< "$USETO $DEVIDE")
MIN_SPARE=$(awk '{print int($1/($2/1024)*0.25)}' <<< "$PER_MEMORY $CHILD")
MAX_SPARE=$(awk '{print int($1/($2/1024)*0.75)}' <<< "$PER_MEMORY $CHILD")
START_SERVER=$(awk '{print int($1+($2-$1)/2)}' <<< "$MIN_SPARE $MAX_SPARE")
MAX_CHILD=$(awk '{print int($1/($2/1024))}' <<< "$PER_MEMORY $CHILD")
if [[ $MIN_SPARE -le 1 ]];then MIN_SPARE=1;fi
if [[ $MAX_SPARE -le 3 ]];then MAX_SPARE=3;fi
if [[ $START_SERVER -le 2 ]];then START_SERVER=2;fi
if [[ $MAX_CHILD -le 5 ]];then MAX_CHILD=5;fi

echo -e "pm                              = dynamic\npm.max_children                 = ${MAX_CHILD}
pm.start_servers                = ${START_SERVER}\npm.min_spare_servers            = ${MIN_SPARE}
pm.max_spare_servers            = ${MAX_SPARE}\npm.max_requests                 = 500"
echo -e $TearOff

exit 0
