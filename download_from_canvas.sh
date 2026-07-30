#!/bin/bash

# Configuration
FOLDER=$1"_"$2
SUBM_ID=$2
ANON=$3

TOKEN=$(cat .token)

COURSE_ID="5718"
BASE_URL="https://lms.skoltech.ru/api/v1/courses/$COURSE_ID/assignments/$SUBM_ID/submissions?"
USERS_URL="https://lms.skoltech.ru/api/v1/courses/$COURSE_ID/assignments/$SUBM_ID/gradeable_students?"

PER_PAGE=50
MAX_PAGES=5  

OUTPUT_DIR=$FOLDER"/temp_pages"
MERGED_FILE=$FOLDER"/out_merged.txt"
MERGED_USERS=$FOLDER"/user_merged.txt"
FINAL_FILE=$FOLDER"/out.txt"
FINAL_USERS=$FOLDER"/users.txt"

printf '#%.0s' {1..20}
echo " download started"

# Create temporary directory for page files
mkdir -p "$FOLDER"
mkdir -p "$OUTPUT_DIR"

# Download pages until empty or max pages reached
page=1
while [ $page -le $MAX_PAGES ]; do
  OUTPUT_FILE="$OUTPUT_DIR/out_page_${page}.txt"
  OUTPUT_FILE_USER="$OUTPUT_DIR/out_user_${page}.txt"
  echo "Downloading page $page to $OUTPUT_FILE..."

  # Download with curl
  curl -L -H "Authorization: Bearer $TOKEN" \
     --max-time 300 \
     --retry 3 \
     --compressed \
     -o "$OUTPUT_FILE" \
     "${BASE_URL}&per_page=${PER_PAGE}&page=${page}"

  if ! $ANON; then
  curl -L -H "Authorization: Bearer $TOKEN" \
    --max-time 300 \
    --retry 3 \
    --compressed \
    -o "$OUTPUT_FILE_USER" \
    "${USERS_URL}&per_page=${PER_PAGE}&page=${page}"
  fi

  # Check if download was successful
  if [ $? -ne 0 ]; then
  echo "Error downloading page $page. Exiting."
  exit 1
  fi

  # Check if file is empty or contains no items (for JSON, check array length)
  if [ ! -s "$OUTPUT_FILE" ]; then
  echo "Page $page is empty. Stopping."
  rm "$OUTPUT_FILE"  # Remove empty file
  break
  fi

  # If JSON, check item count (requires jq)
  if command -v jq >/dev/null 2>&1; then
  item_count=$(jq '. | length' "$OUTPUT_FILE" 2>/dev/null || echo 0)
  if [ "$item_count" -eq 0 ]; then
    echo "Page $page has no items. Stopping."
    rm "$OUTPUT_FILE"
    break
  fi
  fi

  ((page++))
done


# Check if any files were downloaded
if ! ls "$OUTPUT_DIR"/out_page_*.txt >/dev/null 2>&1; then
  echo "No files downloaded. Check API or token."
  exit 1
fi


# echo "Merging files..."
if head -n 1 "$OUTPUT_DIR/out_page_1.txt" | grep -q '^\['; then
  # JSON array detected, merge into single array
  echo "[" > "$MERGED_FILE"
  first=1
  for file in "$OUTPUT_DIR"/out_page_*.txt; do
  if [ $first -eq 1 ]; then
    sed '1s/^\[//' "$file" | sed '$s/\]$//' >> "$MERGED_FILE"
    first=0
  else
    echo "," >> "$MERGED_FILE"
    sed '1s/^\[//' "$file" | sed '$s/\]$//' >> "$MERGED_FILE"
  fi
  done
  echo "]" >> "$MERGED_FILE"
else
  # Plain text, simple concatenation
  cat "$OUTPUT_DIR"/out_page_*.txt > "$MERGED_FILE"
fi

# echo "Applying regex replacement..."
sed 's/{/\n{/g' "$MERGED_FILE" > "$FINAL_FILE"



# echo "Verifying output..."
if command -v jq >/dev/null 2>&1 && head -n 1 "$FINAL_FILE" | grep -q '^\['; then
  item_count=$(jq '. | length' "$FINAL_FILE" 2>/dev/null || echo "Invalid JSON")
  echo "Total items in $FINAL_FILE: $item_count"
else
  echo "Line count in $FINAL_FILE: $(wc -l < "$FINAL_FILE")"
fi



if ! $ANON; then
  if head -n 1 "$OUTPUT_DIR/out_user_1.txt" | grep -q '^\['; then
  # JSON array detected, merge into single array
  echo "[" > "$MERGED_USERS"
  first=1
  for file in "$OUTPUT_DIR"/out_user_*.txt; do
    if [ $first -eq 1 ]; then
    sed '1s/^\[//' "$file" | sed '$s/\]$//' >> "$MERGED_USERS"
    first=0
    else
    echo "," >> "$MERGED_USERS"
    sed '1s/^\[//' "$file" | sed '$s/\]$//' >> "$MERGED_USERS"
    fi
  done
  echo "]" >> "$MERGED_USERS"
  else
  # Plain text, simple concatenation
  cat "$OUTPUT_DIR"/out_user_*.txt > "$MERGED_USERS"
  fi

  # echo "Applying regex replacement..."
  sed 's/{/\n{/g' "$MERGED_USERS" > "$FINAL_USERS"

  rm -f "$MERGED_USERS"
fi

# Clean up temporary files
echo "Cleaning up..."
rm -rf "$OUTPUT_DIR"
rm -f "$MERGED_FILE" 

printf '#%.0s' {1..20}
echo " download finished"