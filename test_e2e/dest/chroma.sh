#!/usr/bin/env bash

set -e

SRC_PATH=$(dirname "$(realpath "$0")")
SCRIPT_DIR=$(dirname "$SRC_PATH")
cd "$SCRIPT_DIR"/.. || exit 1
OUTPUT_FOLDER_NAME=chroma-dest
OUTPUT_DIR=$SCRIPT_DIR/structured-output/$OUTPUT_FOLDER_NAME
WORK_DIR=$SCRIPT_DIR/workdir/$OUTPUT_FOLDER_NAME
DOWNLOAD_DIR=$SCRIPT_DIR/download/$OUTPUT_FOLDER_NAME
max_processes=${MAX_PROCESSES:=$(python3 -c "import os; print(os.cpu_count())")}
CI=${CI:-"false"}

RANDOM_SUFFIX=$((RANDOM % 100000 + 1))

COLLECTION_NAME="chroma-test-output-$RANDOM_SUFFIX"

# shellcheck disable=SC1091
source "$SCRIPT_DIR"/cleanup.sh

function cleanup() {
  # Kill chroma background process
  docker compose -f "$SCRIPT_DIR"/env_setup/chroma/docker-compose.yml down --remove-orphans -v
  cleanup_dir "$OUTPUT_DIR"
  cleanup_dir "$WORK_DIR"
  if [ "$CI" == "true" ]; then
    cleanup_dir "$DOWNLOAD_DIR"
  fi
}

trap cleanup EXIT

# Run chroma from different script so it can be forced into background
docker compose -f "$SCRIPT_DIR"/env_setup/chroma/docker-compose.yml up -d --wait

PYTHONPATH=. ./unstructured_ingest/main.py \
  local \
  --api-key "$UNS_PAID_API_KEY" \
  --partition-by-api \
  --partition-endpoint "https://api.unstructuredapp.io" \
  --num-processes "$max_processes" \
  --output-dir "$OUTPUT_DIR" \
  --strategy fast \
  --verbose \
  --input-path example-docs/book-war-and-peace-1p.txt \
  --work-dir "$WORK_DIR" \
  --chunking-strategy by_title \
  --chunk-max-characters 1500 \
  --chunk-multipage-sections \
  --embedding-provider "huggingface" \
  chroma \
  --host "localhost" \
  --port 8000 \
  --collection-name "$COLLECTION_NAME" \
  --tenant "default_tenant" \
  --database "default_database" \
  --batch-size 80

python "$SCRIPT_DIR"/python/test-ingest-chroma-output.py --collection-name "$COLLECTION_NAME"
