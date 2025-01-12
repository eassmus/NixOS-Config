#!/usr/bin/bash

declare -i scalar="$1"

read float < <(light -G)
CURR=$(awk '{printf "%d", $1}' <<< "$float")
mult=2
cutoff=20
echo $CURR
if [[ $CURR -lt $cutoff ]]; then
  change=$((scalar / mult))
  echo $cutoff
  echo $scalar
  echo $change
else 
  change=$((scalar))
fi



neg=-1
zero=0
if [[ $change -lt $zero ]]; then
  light -U $(($neg * $change))
else
  light -A $change
fi

