#!/bin/bash
#(base)% msmtp --file=.msmtprc andrew4ig@yandex.ru < test_email.txt # wroked

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

FROM="andrew4ig@yandex.ru"
# RECIPIENTS=("d.kulish@skoltech.ru" "andrei.aleksandrov@skoltech.ru")
# TO=$(IFS=,; echo "${RECIPIENTS[*]}")

declare -a TO=("d.kulish@skoltech.ru" "andrei.aleksandrov@skoltech.ru")


SUBJECT="Email with Attachment for assigments for "$TITLE
BODY="This is the email with attachement.\nRegards,\nAndrei Aleksandrov"

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

