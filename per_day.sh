#!/usr/bin/env bash
set -euo pipefail

DATE="$1"; ID="$2"; ANON="$3"

# bash ./download_from_canvas.sh "$DATE" "$ID" "$ANON"
bash ./txt_to_pdf.sh          "$DATE" "$ID" "$ANON"
# bash ./send_mail.sh         "$DATE" "$ID" "$ANON"