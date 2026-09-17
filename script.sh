#!/usr/bin/env bash
set -uo pipefail

cd ~/Documents/Skoltech/others/IW26/canvas

DATE='2026_09_11'
# DATE="${1:-$(date +%Y_%m_%d)}"

run_for() {
    local dates_file="$1" anon="$2" label="$3"
    local id
    id=$(awk -v d="$DATE" '$1 == d {print $2; exit}' "$dates_file")
    if [ -z "$id" ]; then
        echo "No ${label} assignment for ${DATE}"
        return
    fi
    echo "date: ${DATE}  id: ${id}  anon: ${anon}  (${label})"
    bash ./per_day.sh "$DATE" "$id" "$anon"
}

run_for dates_MUDCARDid.txt true  MUDCARD
run_for dates_HWid.txt      false HW