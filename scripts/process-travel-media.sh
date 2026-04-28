#!/bin/bash
# process-travel-media.sh
# Complete pipeline for processing travel images and GPX tracks
# Usage: ./process-travel-media.sh <source_dir> <output_dir>

set -e

SOURCE_DIR="$1"
OUTPUT_DIR="${2:-$SOURCE_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Travel Media Processing Pipeline"
    echo ""
    echo "Usage: $0 <source_dir> [output_dir]"
    echo ""
    echo "Processes images and GPX files for the travel-log web app."
    echo ""
    echo "Pipeline steps:"
    echo "  1. Convert images to WebP (full-size + thumbnails)"
    echo "  2. Extract EXIF GPS data from images"
    echo "  3. Extract metadata from GPX tracks"
    echo ""
    echo "Required tools: imagemagick (or magick), exiftool, python3"
    exit 1
}

check_dependencies() {
    local missing=()
    
    if ! command -v convert &> /dev/null && ! command -v magick &> /dev/null; then
        missing+=("imagemagick")
    fi
    
    if ! command -v exiftool &> /dev/null; then
        missing+=("exiftool")
    fi
    
    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Missing dependencies: ${missing[*]}${NC}"
        echo "Install with: pkg install ${missing[*]}"
        exit 1
    fi
}

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Travel Media Processing Pipeline                        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check args
if [[ -z "$SOURCE_DIR" ]]; then
    usage
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo -e "${RED}Error: Source directory not found: $SOURCE_DIR${NC}"
    exit 1
fi

check_dependencies

# Set up output directories
IMAGES_DIR="$OUTPUT_DIR/images"
THUMBS_DIR="$OUTPUT_DIR/thumbnails"
mkdir -p "$IMAGES_DIR" "$THUMBS_DIR"

echo -e "${GREEN}Source:${NC}  $SOURCE_DIR"
echo -e "${GREEN}Output:${NC}  $OUTPUT_DIR"
echo ""

# ═══════════════════════════════════════════════════════════════
# Step 1: Convert Images
# ═══════════════════════════════════════════════════════════════
echo -e "${YELLOW}▸ Step 1: Converting images to WebP${NC}"

# Find all image files
mapfile -t image_files < <(
    find "$SOURCE_DIR" -maxdepth 1 -type f \( \
        -iname "*.jpg" -o -iname "*.jpeg" -o \
        -iname "*.png" -o -iname "*.webp" -o \
        -iname "*.heic" -o -iname "*.avif" \
    \) 2>/dev/null | sort
)

if [[ ${#image_files[@]} -eq 0 ]]; then
    echo -e "${YELLOW}  No images found to convert${NC}"
else
    echo -e "  Found ${#image_files[@]} image(s)"
    
    converted=0
    for img in "${image_files[@]}"; do
        filename=$(basename "$img")
        name="${filename%.*}"
        
        # Check if already WebP and same date
        if [[ "${filename,,}" == *.webp ]]; then
            echo -e "  ${YELLOW}↷${NC} Skipping (already WebP): $filename"
            continue
        fi
        
        # Full-size WebP (max 2048px, quality 85)
        if command -v convert &> /dev/null; then
            convert "$img" -quality 85 -resize 2048x2048\> "$IMAGES_DIR/${name}.webp"
        else
            magick "$img" -quality 85 -resize 2048x2048\> "$IMAGES_DIR/${name}.webp"
        fi
        
        # Thumbnail (300x300, quality 80, square crop)
        thumb_size=300
        if command -v convert &> /dev/null; then
            convert "$img" -quality 80 -resize "${thumb_size}x${thumb_size}"^ \
                -gravity center -extent "${thumb_size}x${thumb_size}" \
                "$THUMBS_DIR/${name}.webp"
        else
            magick "$img" -quality 80 -resize "${thumb_size}x${thumb_size}"^ \
                -gravity center -extent "${thumb_size}x${thumb_size}" \
                "$THUMBS_DIR/${name}.webp"
        fi
        
        echo -e "  ${GREEN}✓${NC} $filename -> ${name}.webp"
        ((converted++)) || true
    done
    
    echo -e "  ${GREEN}Converted $converted image(s)${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
# Step 2: Extract Image Metadata (GPS + timestamps)
# ═══════════════════════════════════════════════════════════════
echo -e "${YELLOW}▸ Step 2: Extracting image EXIF metadata${NC}"

images_json="$OUTPUT_DIR/images.json"
echo "[" > "$images_json"
first=true

for img in "$IMAGES_DIR"/*.webp "$THUMBS_DIR"/*.webp; do
    [[ -f "$img" ]] || continue
    
    filename=$(basename "$img")
    name="${filename%.*}"
    
    # Try original source image for EXIF
    src_img=""
    for ext in jpg jpeg png heic avif; do
        if [[ -f "$SOURCE_DIR/${name}.$ext" ]]; then
            src_img="$SOURCE_DIR/${name}.$ext"
            break
        fi
    done
    
    # Get EXIF from source or current file
    lat=$(exiftool -s -s -s -GPSLatitude "${src_img:-$img}" 2>/dev/null || echo "")
    lon=$(exiftool -s -s -s -GPSLongitude "${src_img:-$img}" 2>/dev/null || echo "")
    datetime=$(exiftool -s -s -s -DateTimeOriginal "${src_img:-$img}" 2>/dev/null || echo "")
    
    if [[ -n "$lat" ]]; then
        if [[ "$first" == true ]]; then
            first=false
        else
            echo "," >> "$images_json"
        fi
        
        cat << EOF >> "$images_json"
  {
    "file": "$filename",
    "lat": "$lat",
    "lon": "$lon",
    "date": "$datetime"
  }
EOF
        echo -e "  ${GREEN}✓${NC} $filename (lat: $lat)"
    else
        echo -e "  ${YELLOW}–${NC} $filename (no GPS data)"
    fi
done

echo "]" >> "$images_json"
echo -e "  ${GREEN}Saved to $images_json${NC}"

echo ""

# ═══════════════════════════════════════════════════════════════
# Step 3: Extract GPX Track Data
# ═══════════════════════════════════════════════════════════════
echo -e "${YELLOW}▸ Step 3: Extracting GPX track metadata${NC}"

gpx_files=$(find "$SOURCE_DIR" -maxdepth 1 -name "*.gpx" 2>/dev/null | sort)

if [[ -z "$gpx_files" ]]; then
    echo -e "${YELLOW}  No GPX files found${NC}"
else
    for gpx in $gpx_files; do
        filename=$(basename "$gpx")
        name="${filename%.*}"
        output_json="$OUTPUT_DIR/${name}_data.json"
        
        # Parse GPX with Python
        python3 << PYTHON_SCRIPT
import sys
import json
import xml.etree.ElementTree as ET
from datetime import datetime
import math

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    lat1_rad, lat2_rad = math.radians(lat1), math.radians(lat2)
    dlat, dlon = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(lat1_rad)*math.cos(lat2_rad)*math.sin(dlon/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

def parse_gpx(gpx_path):
    tree = ET.parse(gpx_path)
    root = tree.getroot()
    ns = {'gpx': 'http://www.topografix.com/GPX/1/1'}
    
    name = ""
    metadata = root.find('gpx:metadata', ns)
    if metadata is not None:
        n = metadata.find('gpx:name', ns)
        if n is not None and n.text:
            name = n.text
    
    total_dist = 0.0
    min_ele, max_ele = float('inf'), float('-inf')
    start_time, end_time = None, None
    
    for track in root.findall('.//gpx:trk', ns):
        if not name:
            tn = track.find('gpx:name', ns)
            if tn is not None and tn.text:
                name = tn.text
        
        for seg in track.findall('gpx:trkseg', ns):
            prev_pt = None
            for pt in seg.findall('gpx:trkpt', ns):
                lat, lon = float(pt.get('lat')), float(pt.get('lon'))
                ele_e = pt.find('gpx:ele', ns)
                ele = float(ele_e.text) if ele_e is not None and ele_e.text else 0.0
                time_e = pt.find('gpx:time', ns)
                time_str = time_e.text if time_e is not None else None
                
                min_ele = min(min_ele, ele)
                max_ele = max(max_ele, ele)
                
                if time_str:
                    try:
                        dt = datetime.fromisoformat(time_str.replace('Z', '+00:00'))
                        if start_time is None: start_time = dt
                        end_time = dt
                    except: pass
                
                if prev_pt:
                    total_dist += haversine(prev_pt[0], prev_pt[1], lat, lon)
                prev_pt = (lat, lon)
    
    duration = int((end_time - start_time).total_seconds()) if start_time and end_time else 0
    h, m = duration // 3600, (duration % 3600) // 60
    dur_str = f"{h}h {m}m" if h > 0 else f"{m}m"
    
    result = {
        "name": name,
        "distance_km": round(total_dist / 1000, 1),
        "distance_formatted": f"{round(total_dist / 1000, 1)} km",
        "elevation_min_m": int(min_ele) if min_ele != float('inf') else 0,
        "elevation_max_m": int(max_ele) if max_ele != float('-inf') else 0,
        "elevation_formatted": f"{int(min_ele) if min_ele != float('inf') else 0}m – {int(max_ele) if max_ele != float('-inf') else 0}m",
        "duration_formatted": dur_str
    }
    
    with open("${output_json}", 'w') as f:
        json.dump(result, f, indent=2)
    print(f"Saved: ${output_json}")

parse_gpx("${gpx}")
PYTHON_SCRIPT
        
        echo -e "  ${GREEN}✓${NC} $filename -> ${name}_data.json"
    done
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Pipeline complete!${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Output directory: ${OUTPUT_DIR}"
echo -e "  ├── images/        (full-size WebP)"
echo -e "  ├── thumbnails/    (300x300 WebP)"
echo -e "  ├── images.json    (GPS metadata)"
echo -e "  └── *_data.json    (GPX track data)"
echo ""