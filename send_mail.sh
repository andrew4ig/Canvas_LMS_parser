#!/bin/bash

FOLDER=$1"_"$2
ANON=$3
if $ANON; then
  TITLE="MUDCARDS_"$FOLDER
else
  TITLE="HW_"$FOLDER
fi

printf '#%.0s' {1..20}
echo " mailing started"

ATTACHMENT=$FOLDER"/"$FOLDER".pdf"

FROM=$(grep sender .info | awk '{print $2}')

declare -a TO=($(grep '^recipents' .info | cut -d' ' -f2-))

SUBJECT="Email with Attachment for assigments for "$TITLE
BODY="This is the email with attachement for $TITLE.\nRegards"

BOUNDARY="boundary_string_$(date +%s)"

if [ ! -f "$ATTACHMENT" ]; then
    echo "Error: File $ATTACHMENT does not exist"
    exit 1
fi

if [ ! -r "$ATTACHMENT" ]; then
    echo "Error: File $ATTACHMENT is not readable"
    exit 1
fi

for RECIPIENT in "${TO[@]}"; do
    {
        echo "From: $FROM"
        echo "To: $RECIPIENT"
        echo "Subject: $SUBJECT"
        echo "MIME-Version: 1.0"
        echo "Content-Type: multipart/mixed; boundary=\"$BOUNDARY\""
        echo ""
        echo "--$BOUNDARY"
        echo "Content-Type: text/plain; charset=UTF-8"
        echo "Content-Transfer-Encoding: 7bit"
        echo ""
        echo -e "$BODY"
        echo ""
        echo "--$BOUNDARY"
        echo "Content-Type: application/octet-stream; name=\"$(basename "$ATTACHMENT")\""
        echo "Content-Transfer-Encoding: base64"
        echo "Content-Disposition: attachment; filename=\"$(basename "$ATTACHMENT")\""
        echo ""
        base64 -i "$ATTACHMENT"
        echo ""
        echo "--$BOUNDARY--"
    } > email.txt
    msmtp --file=.msmtprc "$RECIPIENT" < email.txt
    sleep 2s
done

rm email.txt

printf '#%.0s' {1..20}
echo " mailing finished"


################################################################################

#!/usr/bin/env bash
set -uo pipefail

FOLDER="${1}_${2}"
ANON="${3:-false}"

if $ANON; then TITLE="MUDCARDS_${FOLDER}"; else TITLE="HW_${FOLDER}"; fi

echo "---- mailing started ----"

ATTACHMENT="${FOLDER}/${FOLDER}.pdf"
if [ ! -r "$ATTACHMENT" ]; then
    echo "Error: ${ATTACHMENT} missing or unreadable" >&2
    exit 1
fi

FROM=$(awk '/^sender/ {print $2; exit}' .info)
if [ -z "$FROM" ]; then
    echo "Error: 'sender' missing from .info" >&2
    exit 1
fi

SUBJECT="Email with attachment for assignments for ${TITLE}"
BODY="This is the email with attachment for ${TITLE}.\nRegards"
BOUNDARY="boundary_$(date +%s)_$$"
BASENAME=$(basename "$ATTACHMENT")

# Pre-encode the attachment once, wrapped at 76 chars per RFC 2045
ENCODED_FILE=$(mktemp)
trap 'rm -f "$ENCODED_FILE"' EXIT
base64 < "$ATTACHMENT" | tr -d '\n' | fold -w 76 > "$ENCODED_FILE"

while IFS= read -r RECIPIENT; do
    [ -n "$RECIPIENT" ] || continue
    {
        printf 'From: %s\n' "$FROM"
        printf 'To: %s\n' "$RECIPIENT"
        printf 'Subject: %s\n' "$SUBJECT"
        printf 'MIME-Version: 1.0\n'
        printf 'Content-Type: multipart/mixed; boundary="%s"\n\n' "$BOUNDARY"
        printf -- '--%s\n' "$BOUNDARY"
        printf 'Content-Type: text/plain; charset=UTF-8\n'
        printf 'Content-Transfer-Encoding: 7bit\n\n'
        printf '%b\n\n' "$BODY"
        printf -- '--%s\n' "$BOUNDARY"
        printf 'Content-Type: application/octet-stream; name="%s"\n' "$BASENAME"
        printf 'Content-Transfer-Encoding: base64\n'
        printf 'Content-Disposition: attachment; filename="%s"\n\n' "$BASENAME"
        cat "$ENCODED_FILE"
        printf '\n--%s--\n' "$BOUNDARY"
    } | msmtp --file=.msmtprc "$RECIPIENT" \
        && echo "Sent to $RECIPIENT" \
        || echo "Failed to send to $RECIPIENT" >&2
    sleep 2
done < <(awk '/^recipents/ {for (i=2; i<=NF; i++) print $i}' .info)

echo "---- mailing finished ----"