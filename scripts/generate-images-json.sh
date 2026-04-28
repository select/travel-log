#!/bin/bash
# generate-images-json.sh
# Extracts GPS/timestamp from source JPG images and creates/extends images.json
# Usage: ./generate-images-json.sh [source_dir] [output_json]
# Preserves existing entries, adds new ones for webp files not yet in JSON

set -e

SOURCE_DIR="${1:-/data/data/com.termux/files/home/storage/shared/dev}"
OUTPUT_JSON="${2:-public/images.json}"
PUBLIC_DIR="public"
IMAGES_DIR="$PUBLIC_DIR/images"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

check_dependencies() {
    if ! command -v exiftool &> /dev/null; then
        echo -e "${RED}Error: exiftool required${NC}"
        exit 1
    fi
}

generate_images_json() {
    local source_dir="$1"
    local output_file="$2"
    
    echo -e "${CYAN}Generating images.json from source images...${NC}"
    
    python3 - "$source_dir" "$output_file" << 'PYEOF'
import sys
import json
import subprocess
import os

source_dir = sys.argv[1]
output_file = sys.argv[2]
images_dir = "public/images"

# Load existing images.json if it exists
existing = {}
if os.path.exists(output_file):
    try:
        with open(output_file) as f:
            data = json.load(f)
        for item in data:
            existing[item["file"]] = item
        print(f"  Loaded {len(existing)} existing entries")
    except:
        existing = {}

# Get all webp files in images dir
webp_files = sorted([f for f in os.listdir(images_dir) if f.endswith('.webp')])
print(f"  Found {len(webp_files)} webp files")

# Process each webp file
new_count = 0
for webp in webp_files:
    if webp in existing:
        print(f"  = {webp} (kept existing)")
        continue
    
    name = webp.replace('.webp', '')
    
    # Try both .jpg and .JPG extensions
    src_jpg = os.path.join(source_dir, f"{name}.jpg")
    if not os.path.exists(src_jpg):
        src_jpg = os.path.join(source_dir, f"{name}.JPG")
    
    lat = lon = date = ""
    
    if os.path.exists(src_jpg):
        try:
            lat = subprocess.check_output(
                ['exiftool', '-s', '-s', '-s', '-GPSLatitude', src_jpg],
                text=True, stderr=subprocess.DEVNULL
            ).strip()
            lon = subprocess.check_output(
                ['exiftool', '-s', '-s', '-s', '-GPSLongitude', src_jpg],
                text=True, stderr=subprocess.DEVNULL
            ).strip()
            date = subprocess.check_output(
                ['exiftool', '-s', '-s', '-s', '-DateTimeOriginal', src_jpg],
                text=True, stderr=subprocess.DEVNULL
            ).strip()
        except:
            pass
    
    existing[webp] = {
        "file": webp,
        "lat": lat,
        "lon": lon,
        "date": date
    }
    
    status = "GPS" if lat else "no GPS"
    print(f"  + {webp} ({status})")
    new_count += 1

# Sort by filename and save
images = sorted(existing.values(), key=lambda x: x["file"])

with open(output_file, 'w') as f:
    json.dump(images, f, indent=2)

print(f"\nSaved {len(images)} entries ({new_count} new) to {output_file}")
PYEOF
}

check_dependencies

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo -e "${RED}Error: Source directory not found: $SOURCE_DIR${NC}"
    exit 1
fi

generate_images_json "$SOURCE_DIR" "$OUTPUT_JSON"