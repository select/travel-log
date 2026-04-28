#!/bin/bash
# extract-image-metadata.sh
# Extracts EXIF GPS data and timestamps from images for map photo markers
# Usage: ./extract-image-metadata.sh [-o output.json] <image_file> [...]

set -e

OUTPUT_FILE=""
IMAGES=()

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_dependencies() {
    if ! command -v exiftool &> /dev/null; then
        echo -e "${RED}Error: exiftool is required. Install with: pkg install exiftool${NC}"
        exit 1
    fi
}

get_image_json() {
    local img="$1"
    
    local lat_dms lon_dms datetime filename name
    
    lat_dms=$(exiftool -s -s -s -GPSLatitude "$img" 2>/dev/null || echo "")
    lon_dms=$(exiftool -s -s -s -GPSLongitude "$img" 2>/dev/null || echo "")
    datetime=$(exiftool -s -s -s -DateTimeOriginal "$img" 2>/dev/null || echo "")
    
    filename=$(basename "$img")
    name="${filename%.*}"
    
    # Output JSON object (matching existing images.json format)
    echo "  {"
    echo "    \"file\": \"${name}.webp\","
    echo "    \"lat\": \"${lat_dms}\","
    echo "    \"lon\": \"${lon_dms}\","
    echo "    \"date\": \"${datetime}\""
    echo "  }"
}

# Parse arguments
while [[ "$1" == -* ]]; do
    case "$1" in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-o output.json] <image_file> [...]"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

IMAGES=("$@")

if [[ ${#IMAGES[@]} -eq 0 ]]; then
    echo "Usage: $0 [-o output.json] <image_file> [...]"
    exit 1
fi

check_dependencies

echo -e "${GREEN}Extracting metadata from ${#IMAGES[@]} image(s)...${NC}"

# Build JSON array
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "[" > "$OUTPUT_FILE"
else
    echo "["
fi

first=true
for img in "${IMAGES[@]}"; do
    if [[ ! -f "$img" ]]; then
        echo -e "${YELLOW}Skipping (not found): $img${NC}"
        continue
    fi
    
    lat=$(exiftool -s -s -s -GPSLatitude "$img" 2>/dev/null || echo "")
    
    if [[ "$first" == true ]]; then
        first=false
    else
        if [[ -n "$OUTPUT_FILE" ]]; then
            echo "," >> "$OUTPUT_FILE"
        else
            echo ","
        fi
    fi
    
    get_image_json "$img"
    
    if [[ -n "$lat" ]]; then
        echo -e "  ${GREEN}✓${NC} $(basename "$img") (has GPS)"
    else
        echo -e "  ${YELLOW}–${NC} $(basename "$img") (no GPS)"
    fi
done

if [[ -n "$OUTPUT_FILE" ]]; then
    echo "]" >> "$OUTPUT_FILE"
    echo -e "${GREEN}✓${NC} Saved to $OUTPUT_FILE"
else
    echo "]"
fi