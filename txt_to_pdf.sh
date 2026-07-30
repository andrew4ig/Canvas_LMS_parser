#!/bin/bash

FOLDER=$1"_"$2
ANON=$3
echo "ANON=$ANON"
INPUT_FILE=$FOLDER"/out.txt"
HTML_FILE=$FOLDER"/out.html"
TEMP_BODIES=$FOLDER"/temp_bodies.txt"
TEMP_SHUFFLED_BODIES=$FOLDER"/temp_bodies_shuffled.txt"
FINAL_FILE=$FOLDER"/out_modified.html"
PDF_FILE=$FOLDER"/"$FOLDER".pdf"

if ! $ANON; then
  USERS=$FOLDER"/users.txt"
  SUBM_USER_ID=$FOLDER"/subm_users_id.txt"
  jq -r '.[] | select(.id != "" and .id != null) | [.id, .display_name] | join(",")' "$USERS" > "$SUBM_USER_ID"
fi

printf '#%.0s' {1..20}
echo " PDFer started"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required for JSON parsing. Install it (e.g., sudo apt install jq)."
  exit 1
fi

if ! command -v wkhtmltopdf >/dev/null 2>&1; then
  echo "Error: wkhtmltopdf is required for PDF conversion. Install it (e.g., sudo apt install wkhtmltopdf)."
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: $INPUT_FILE not found. Run download_merge.sh first."
  exit 1
fi


if ! $ANON; then
  jq -r '.[] | select(.body != "" and .body != "null") | [.user_id, .body] | @tsv' "$INPUT_FILE" | while IFS=$'\t' read -r id body; do
    if [ -z "$id" ] || ! [[ "$id" =~ ^[0-9]+$ ]]; then
      name="Unknown"
    else
      name=$(awk -F, -v id="$id" '$1 == id {print $2}' "$SUBM_USER_ID" | head -n 1 | tr -d '\r\n\t')
      if [ -z "$name" ]; then
        name="Unknown"
      fi
    fi

    echo "HEADOPEN${name}HEADCLOSE \\n ${body}" | jq -R '
      gsub("null"; "") |
      gsub("&nbsp"; "") |
      gsub("</?([[:alnum:]]+)[^>]*>"; " ") |
      gsub(" +"; " ") |
      gsub("^ ?<br>+|<br> ?+$"; "") |
      . + "</div>" |
      gsub("<br></div>"; "</div>")
    '
  done > "$TEMP_BODIES"
  sed 's/"//g' "$TEMP_BODIES" > temp.txt
  mv temp.txt "$TEMP_BODIES"
  sed -E 's#\\\\n#<br>#g' "$TEMP_BODIES" > temp.txt
  mv temp.txt "$TEMP_BODIES"
  sed -E "s#(<br> ?)+#<br>#g" "$TEMP_BODIES" > temp.txt
  mv temp.txt "$TEMP_BODIES"
  sed -E "s#HEADOPEN#<h1>#g" "$TEMP_BODIES" > temp.txt
  mv temp.txt "$TEMP_BODIES"
  sed -E "s#HEADCLOSE#</h1>#g" "$TEMP_BODIES" > temp.txt
  mv temp.txt "$TEMP_BODIES"
else
  # echo "Extracting valid body fields from $INPUT_FILE..."
  jq -r '
    .[] |
    select(.body != "" and .body != null) |
    .body
    | gsub("null"; "")
    | gsub("&nbsp;"; "")
    | gsub("</?([[:alnum:]]+)[^>]*>"; " ")
    | gsub(" +"; " ")
    | gsub("\n"; "<br>")
    | gsub("(<br> ?)+"; "<br>")
    | gsub("^ ?<br>+|<br> ?+$"; "")
    | . + "</div>"
    | gsub("<br></div>"; "</div>")
  ' "$INPUT_FILE" > "$TEMP_BODIES"
fi
if [ ! -s "$TEMP_BODIES" ]; then
  echo "Error: No valid body fields extracted. Check JSON structure."
  exit 1
fi

cat > "$HTML_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="https://fonts.googleapis.com/css2?family=Roboto&family=Noto+Color+Emoji&display=swap" rel="stylesheet">
  <style>
    @page {
      size: 210mm auto;
      margin: 0;
    }

    html, body {
      width: 205mm;  
      height: auto;   
      margin: 2px;
      padding: 2px;
      font-family: 'Roboto', sans-serif;
    }

    .emoji {
      font-family: 'Noto Color Emoji', sans-serif;
    }

    body, h1, p {
      page-break-before: avoid;
      page-break-after: avoid;
      page-break-inside: avoid;

    }

    h1, p {
      margin: 2px;
      font-size: 20px; 
      font-weight: bolder;
    }

    .body-content {
      border: 1px solid black;
      padding: 2px;
      margin: 2px auto !important;
      width: 98% !important;
      font-size: 16px;
      line-height: 1.5;
      overflow: visible;
      break-inside: avoid;
      box-sizing: border-box;
      display: block;
    }
  </style>
  <title>PDF</title>
  <h1>TITLENAME</h1>
</head>
<body>
EOF

item_count=$(wc -l < "$TEMP_BODIES" | awk '{print int($1/2)}')
if [ "$item_count" -eq 0 ]; then
  echo "Warning: No valid body items found, using default height 1000mm"
  estimated_height=1000
else
  total_height=0
  while IFS= read -r -d $'---' body && [ -n "$body" ]; do
    block_count=$(echo "$body" | grep -Eic '</(p|div|h[1-6]|li|br)>' || echo 0)
    if ! [[ "$block_count" =~ ^[0-9]+$ ]]; then
      block_count=0
    fi
    char_count=$(echo -n "$body" | tr -d '\n' | wc -c | awk '{print $1}')
    if ! [[ "$char_count" =~ ^[0-9]+$ ]] || [ "$char_count" -lt 1 ]; then
      char_count=120  
    fi
    text_lines=$(( (char_count + 99) / 100 ))
    if [ "$block_count" -gt "$text_lines" ]; then
      line_count=$block_count
    else
      line_count=$text_lines
    fi
    line_count=$((line_count < 1 ? 1 : line_count))
    body_height=$(echo "scale=6; ($line_count * 24) + (22)" | bc)
    total_height=$(echo "scale=6; $total_height + $body_height * 0.45" | bc)
  done < "$TEMP_BODIES"
  total_height=$(echo "scale=6; $total_height + 100" | bc)
  estimated_height=$(printf "%.0f" "$total_height")
  if ! [[ "$estimated_height" =~ ^[0-9]+$ ]] || [ "$estimated_height" -lt 1 ]; then
    echo "Warning: Invalid estimated height ($estimated_height), using 50000mm"
    estimated_height=50000
  fi
  estimated_height=$((estimated_height < 1000 ? 1000 : estimated_height > 50000 ? 50000 : estimated_height))
fi
sed -E "s#size: 210mm auto#size: 210mm ${estimated_height}mm#" "$HTML_FILE" > temp.txt
mv temp.txt "$HTML_FILE"

if $ANON; then
  TITLE="MUDCARDS_"$FOLDER
else
  TITLE="HW_"$FOLDER
fi
sed -E "s#TITLENAME#$TITLE#" "$HTML_FILE" > temp.txt
mv temp.txt "$HTML_FILE"


sort -R "$TEMP_BODIES" > "$TEMP_SHUFFLED_BODIES"
while IFS= read -r body; do
  echo "<div class=\"body-content\">$body" >> "$HTML_FILE"
done < "$TEMP_SHUFFLED_BODIES"

echo "</body>" >> "$HTML_FILE"
echo "</html>" >> "$HTML_FILE"

cp "$HTML_FILE" "$FINAL_FILE"

weasyprint "$HTML_FILE" "$PDF_FILE" --presentational-hints --base-url .
if [ -f "$PDF_FILE" ]; then
  echo "PDF created: $PDF_FILE"
else
  echo "Error: PDF creation failed."
  exit 1
fi

rm $TEMP_BODIES $TEMP_SHUFFLED_BODIES

printf '#%.0s' {1..20}
echo " PDFer ended"