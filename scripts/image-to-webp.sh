#!/bin/bash
# image-to-webp.sh
# Converts images to WebP with full-size and thumbnail outputs
# Skips already converted images, shows progress

INPUT="$1"
OUTPUT_DIR="${2:-.}"

FULL_QUALITY=85
THUMB_QUALITY=80
THUMB_SIZE=300

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

check_converter() {
    if command -v magick &> /dev/null; then
        CONVERT="magick"
    elif command -v convert &> /dev/null; then
        CONVERT="convert"
    elif command -v cwebp &> /dev/null; then
        CONVERT="cwebp"
    else
        echo -e "${RED}Error: No image converter found${NC}"
        exit 1
    fi
}

process_image() {
    local input="$1"
    local output_dir="$2"
    
    case "${input,,}" in
        *.jpg|*.jpeg|*.png|*.webp|*.heic|*.avif) ;;
        *) return 0 ;;
    esac
    
    filename=$(basename "$input")
    name="${filename%.*}"
    
    full_output="$output_dir/images/${name}.webp"
    thumb_output="$output_dir/thumbnails/${name}.webp"
    
    # Skip if already converted
    if [[ -f "$full_output" && -f "$thumb_output" ]]; then
        echo -e "${YELLOW}⇸${NC} Skip (exists): $filename"
        return 0
    fi
    
    mkdir -p "$output_dir/images" "$output_dir/thumbnails"
    
    # Convert to full-size WebP
    if [[ "$CONVERT" == "magick" ]]; then
        magick "$input" -auto-orient -resize 2048x2048\> -quality "$FULL_QUALITY" -strip "$full_output" 2>/dev/null
    elif [[ "$CONVERT" == "convert" ]]; then
        convert "$input" -auto-orient -resize 2048x2048\> -quality "$FULL_QUALITY" -strip "$full_output" 2>/dev/null
    else
        cwebp -q "$FULL_QUALITY" -resize 2048 0 "$input" -o "$full_output" 2>/dev/null
    fi
    
    # Create thumbnail
    if [[ "$CONVERT" == "magick" ]]; then
        magick "$input" -auto-orient -resize "${THUMB_SIZE}x${THUMB_SIZE}"^ \
            -gravity center -extent "${THUMB_SIZE}x${THUMB_SIZE}" -quality "$THUMB_QUALITY" -strip "$thumb_output" 2>/dev/null
    elif [[ "$CONVERT" == "convert" ]]; then
        convert "$input" -auto-orient -resize "${THUMB_SIZE}x${THUMB_SIZE}"^ \
            -gravity center -extent "${THUMB_SIZE}x${THUMB_SIZE}" -quality "$THUMB_QUALITY" -strip "$thumb_output" 2>/dev/null
    else
        cwebp -q "$THUMB_QUALITY" -resize $THUMB_SIZE $THUMB_SIZE "$input" -o "$thumb_output" 2>/dev/null
    fi
    
    # Extract EXIF to JSON using Python for proper escaping
    if command -v exiftool &> /dev/null; then
        lat=$(exiftool -s -s -s -GPSLatitude "$input" 2>/dev/null)
        lon=$(exiftool -s -s -s -GPSLongitude "$input" 2>/dev/null)
        datetime=$(exiftool -s -s -s -DateTimeOriginal "$input" 2>/dev/null)
        
        python3 - "$output_dir/images/${name}.json" "$name.webp" "$lat" "$lon" "$datetime" << 'EOF'
import sys
import json
json_file = sys.argv[1]
file = sys.argv[2]
lat = sys.argv[3] if sys.argv[3] else ""
lon = sys.argv[4] if sys.argv[4] else ""
date = sys.argv[5] if sys.argv[5] else ""
with open(json_file, 'w') as f:
    json.dump({"file": file, "lat": lat, "lon": lon, "date": date}, f)
EOF
    fi
    
    full_size=$(stat -c%s "$full_output" 2>/dev/null || stat -f%z "$full_output" 2>/dev/null || echo "0")
    thumb_size=$(stat -c%s "$thumb_output" 2>/dev/null || stat -f%z "$thumb_output" 2>/dev/null || echo "0")
    
    echo -e "${GREEN}✓${NC} $filename → $(numfmt --to=iec $full_size 2>/dev/null || echo ${full_size}B) / $(numfmt --to=iec $thumb_size 2>/dev/null || echo ${thumb_size}B)"
}

if [[ -z "$INPUT" ]]; then
    echo "Usage: $0 <input_image_or_dir> [output_dir]"
    exit 1
fi

check_converter

if [[ -f "$INPUT" ]]; then
    process_image "$INPUT" "$OUTPUT_DIR"
elif [[ -d "$INPUT" ]]; then
    # Build array of images to process
    images=()
    while IFS= read -r img; do
        [[ -n "$img" ]] && images+=("$img")
    done < <(find "$INPUT" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null | sort)
    
    total=${#images[@]}
    converted=0
    skipped=0
    
    echo -e "${CYAN}Processing $total images (skipping existing)...${NC}"
    
    for img in "${images[@]}"; do
        result=$(process_image "$img" "$OUTPUT_DIR" 2>&1)
        if echo "$result" | grep -q "Skip"; then
            ((skipped++)) || true
        else
            echo "$result"
            ((converted++)) || true
        fi
    done
    
    echo ""
    echo -e "${GREEN}Done: $converted converted, $skipped skipped${NC}"
fi