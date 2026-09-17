#!/bin/bash
set -uo pipefail

FOLDER="${1}_${2}"
ANON="${3:-false}"

INPUT_FILE="${FOLDER}/out.txt"
HTML_FILE="${FOLDER}/out.html"
TEMP_BODIES="${FOLDER}/temp_bodies.txt"
PDF_FILE="${FOLDER}/${FOLDER}.pdf"

if ! $ANON; then
  USERS=$FOLDER"/users.txt"
  SUBM_USER_ID=$FOLDER"/subm_users_id.txt"
  jq -r '.[] | select(.id != "" and .id != null) | [.id, .display_name] | join(",")' "$USERS" > "$SUBM_USER_ID"
fi

echo "---- PDFer started ----"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required for JSON parsing. Install it (e.g., sudo apt install jq)."
  exit 1
fi


if ! command -v wkhtmltopdf >/dev/null 2>&1; then
  echo "Error: wkhtmltopdf is required for PDF conversion. Install it (e.g., sudo apt install wkhtmltopdf)."
  exit 1
fi

for cmd in jq weasyprint python3; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Error: $cmd is required. Install it first." >&2
        exit 1
    }
done

[ -f "$INPUT_FILE" ] || {
    echo "Error: $INPUT_FILE not found. Run download_from_canvas.sh first." >&2
    exit 1
}

# ---------- Extract bodies (ONE line per submission) ----------
JQ_DIR="$(dirname "$0")"          
EMPTY_BODY='<br><br><br>'
if ! $ANON; then
    USERS="${FOLDER}/users.txt"
    SUBM_USER_ID="${FOLDER}/subm_users_id.txt"

    jq -r '.[] | select(.id != null) | [.id, (.display_name // "Unknown")] | @tsv' \
        "$USERS" > "$SUBM_USER_ID"

    # 1) Extract (user_id, cleaned body) as TSV. Body is never empty after
    #    this step — blanks become EMPTY_BODY.
    jq -r -L "$JQ_DIR" --arg empty "$EMPTY_BODY" '
        include "clean";
        .[]
        | [.user_id, ((.body // "") | clean | if . == "" then $empty else . end)]
        | @tsv
    ' "$INPUT_FILE" > "$TEMP_BODIES"

    # 2) Attach names and wrap in <div>. NOTE: everything on ONE line.
    awk -F'\t' -v OFS='\t' '
        NR==FNR { name[$1]=$2; next }
        { n = (name[$1] == "" ? "Unknown" : name[$1]);
          printf "<h1>%s</h1><div class=\"body-content\">%s</div>\n", n, $2 }
    ' "$SUBM_USER_ID" "$TEMP_BODIES" > "${TEMP_BODIES}.named"
    mv "${TEMP_BODIES}.named" "$TEMP_BODIES"
else
    jq -r -L "$JQ_DIR" '
        include "clean";
        .[]
        | select(.body != null and .body != "" and .body != "null")
        | .body | clean
    ' "$INPUT_FILE" \
    | while IFS= read -r body; do
        printf '<div class="body-content">%s</div>\n' "$body"
      done > "$TEMP_BODIES"
fi

if [ ! -s "$TEMP_BODIES" ]; then
    echo "Error: no valid bodies extracted from $INPUT_FILE" >&2
    exit 1
fi

# ---------- HTML shell ----------
if $ANON; then TITLE="MUDCARDS_${FOLDER}"; else TITLE="HomeWork_${FOLDER}"; fi

cat > "$HTML_FILE" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>${TITLE}</title>
<style>
  @page { margin: 4mm; }

  html, body {
    margin: 0; padding: 0;
    font-family: -apple-system, "Helvetica Neue", "Segoe UI", Arial, sans-serif;
    font-weight: 400;
    font-size: 16px;
    line-height: 1.5;
  }
  h1 {
    font-weight: 700;
    font-size: 22px;
    margin: 6px 3px 3px;
    break-after: avoid;
  }
  .body-content {
    border: 1px solid #000;
    padding: 4px;
    margin: 4px auto;
    width: 98%;
    box-sizing: border-box;
    break-inside: avoid;
    overflow-wrap: anywhere;
  }
</style>
</head>
<body>
<h1>${TITLE}</h1>
EOF


# Shuffle to anonymise order, append every body
sort -R "$TEMP_BODIES" >> "$HTML_FILE"
echo "</body></html>" >> "$HTML_FILE"


python3 ./render_pdf.py "$HTML_FILE" "$PDF_FILE"
if [ -f "$PDF_FILE" ]; then
  echo "PDF created: $PDF_FILE"
  echo "---- PDFer ended ----"
else
  echo "Error: PDF creation failed."
  exit 1
fi

rm -f "$TEMP_BODIES"