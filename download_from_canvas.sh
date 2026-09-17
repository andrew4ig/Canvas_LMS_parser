#!/usr/bin/env bash
set -uo pipefail

# Configuration
DATE="${1:?usage: $0 <date> <assignment_id> [anon]}"
SUBM_ID="${2:?usage: $0 <date> <assignment_id> [anon]}"
ANON="${3:-true}"

FOLDER="${DATE}_${SUBM_ID}"
TOKEN=$(awk '/^token/     {print $2; exit}' .info)
COURSE_ID=$(awk '/^COURSE_ID/ {print $2; exit}' .info)

API="https://lms.skoltech.ru/api/v1/courses/${COURSE_ID}/assignments/${SUBM_ID}"
SUBM_URL="${API}/submissions"
USERS_URL="${API}/gradeable_students"

PER_PAGE=50
MAX_PAGES=50

OUTPUT_DIR=$FOLDER"/temp_pages"
# MERGED_FILE=$FOLDER"/out_merged.txt"
# MERGED_USERS=$FOLDER"/user_merged.txt"
FINAL_FILE=$FOLDER"/out.txt"
FINAL_USERS=$FOLDER"/users.txt"

echo "---- download started ----"

# Create temporary directory for page files
mkdir -p "$FOLDER"
mkdir -p "$OUTPUT_DIR"

fetch_all() {
    local url="$1" prefix="$2" page=1
    while [ "$page" -le "$MAX_PAGES" ]; do
        local out="${OUTPUT_DIR}/${prefix}_page_${page}.json"
        echo "Fetching ${prefix} page ${page}..."
        if ! curl -fsSL --max-time 300 --retry 3 --compressed \
                -H "Authorization: Bearer ${TOKEN}" \
                -o "$out" \
                "${url}?per_page=${PER_PAGE}&page=${page}"; then
            echo "Error fetching ${url} page ${page}" >&2
            return 1
        fi
        local count
        count=$(jq 'length' "$out" 2>/dev/null) || count=0
        if [ "$count" -eq 0 ]; then
            rm -f "$out"
            break
        fi
        page=$((page + 1))
    done
}

fetch_all "$SUBM_URL" out || exit 1
if ! $ANON; then
  fetch_all "$USERS_URL" user || exit 1
fi

# Merge via jq — always produces a valid JSON array
shopt -s nullglob
out_pages=("$OUTPUT_DIR"/out_page_*.json)
user_pages=("$OUTPUT_DIR"/user_page_*.json)

if [ ${#out_pages[@]} -eq 0 ]; then
  echo "Error: no submission pages downloaded" >&2
  exit 1
fi


jq -s 'add' "${out_pages[@]}" > "$FINAL_FILE"
if ! $ANON && [ ${#user_pages[@]} -gt 0 ]; then
  jq -s 'add' "${user_pages[@]}" > "$FINAL_USERS"
fi


# # Clean up temporary files
# echo "Cleaning up..."
# rm -rf "$OUTPUT_DIR"


echo "---- download finished ----"
