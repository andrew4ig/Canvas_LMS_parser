#!/bin/bash
date='2025_09_12'
#$(date +%Y_%m_%d)

MUDCARDid=$(grep "$date" dates_MUDCARDid.txt | awk '{print $2}')
ANON=true
echo $'date:\t' "$date" $'\nID:\t' "$MUDCARDid" $'\nAnon:\t' "$ANON"
bash ./per_day.sh $date $MUDCARDid $ANON

# HWid=$(grep "$date" dates_HWid.txt | awk '{print $2}')
# ANON=False
# echo $'date:\t' "$date" $'\nID:\t' "$HWid" $'\nAnon:\t' "$ANON"
# bash ./per_day.sh $date $HWid $ANON

# cron: 1 23 1-30 9 1-5 /script.sh

