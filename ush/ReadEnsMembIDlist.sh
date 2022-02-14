#!/bin/bash

file="ensMembIDlist.txt"
while IFS= read -r line
do
  # display full line, for checking
  printf '%s\n' "$line"
	
  YEAR=$(awk -F' ' '{print $1}' <<< "$line")
  MONTH=$(awk -F' ' '{print $2}' <<< "$line")
  DAY=$(awk -F' ' '{print $3}' <<< "$line")

  wday=$(date -d "$YEAR$MONTH$DAY" +%u)
  if [ "$wday" -eq 3 ]; then
    p05=$(awk -F' ' '{print $4}' <<< "$line")
    p06=$(awk -F' ' '{print $5}' <<< "$line")
    p07=$(awk -F' ' '{print $6}' <<< "$line")
    p08=$(awk -F' ' '{print $7}' <<< "$line")
    p09=$(awk -F' ' '{print $8}' <<< "$line")
    p10=$(awk -F' ' '{print $9}' <<< "$line")

    # display a member, for checking
    printf '%s\n' "$p10"
  fi

done <"$file"
