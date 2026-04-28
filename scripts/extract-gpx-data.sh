#!/bin/bash
# extract-gpx-data.sh
# Extracts data from GPX files for the travel-log web app
# Usage: ./extract-gpx-data.sh <gpx_file> [output_json]
#        or: ./extract-gpx-data.sh --from-index [tracks.json]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <gpx_file> [output_json]"
    echo "       $0 --from-index [tracks.json]"
    echo ""
    echo "Options:"
    echo "  <gpx_file>       Parse single GPX file"
    echo "  --from-index      Parse all GPX files listed in tracks.json"
    echo "  [tracks.json]     Path to tracks.json (default: public/tracks.json)"
    exit 1
}

check_python() {
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: python3 is required${NC}"
        exit 1
    fi
}

parse_gpx() {
    local gpx_file="$1"
    local output_file="$2"
    
    python3 - "$gpx_file" "$output_file" << 'EOF'
import sys
import json
import xml.etree.ElementTree as ET
from datetime import datetime
import math

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    lat1_rad, lat2_rad = math.radians(lat1), math.radians(lat2)
    dlat, dlon = math.radians(lat2-lat1), math.radians(lon2-lon1)
    a = math.sin(dlat/2)**2 + math.cos(lat1_rad)*math.cos(lat2_rad)*math.sin(dlon/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

def parse_gpx(gpx_path):
    tree = ET.parse(gpx_path)
    root = tree.getroot()
    ns = {'gpx': 'http://www.topografix.com/GPX/1/1'}
    
    name = ""
    total_dist = 0.0
    min_ele, max_ele = float('inf'), float('-inf')
    start_time, end_time = None, None
    pt_count = 0
    
    metadata = root.find('gpx:metadata', ns)
    if metadata is not None:
        n = metadata.find('gpx:name', ns)
        if n is not None and n.text:
            name = n.text
    
    for track in root.findall('.//gpx:trk', ns):
        if not name:
            tn = track.find('gpx:name', ns)
            if tn is not None and tn.text:
                name = tn.text
        for seg in track.findall('gpx:trkseg', ns):
            pts = seg.findall('gpx:trkpt', ns)
            pt_count += len(pts)
            prev = None
            for pt in pts:
                lat, lon = float(pt.get('lat')), float(pt.get('lon'))
                ele_e = pt.find('gpx:ele', ns)
                ele = float(ele_e.text) if ele_e is not None and ele_e.text else 0.0
                time_e = pt.find('gpx:time', ns)
                time_str = time_e.text if time_e is not None else None
                min_ele, max_ele = min(min_ele, ele), max(max_ele, ele)
                if time_str:
                    try:
                        dt = datetime.fromisoformat(time_str.replace('Z', '+00:00'))
                        if not start_time: start_time = dt
                        end_time = dt
                    except: pass
                if prev: total_dist += haversine(prev[0], prev[1], lat, lon)
                prev = (lat, lon)
    
    duration = int((end_time - start_time).total_seconds()) if start_time and end_time else 0
    h, m = duration // 3600, (duration % 3600) // 60
    
    return {
        'name': name,
        'file': gpx_path,
        'distance_km': round(total_dist / 1000, 1),
        'distance_formatted': f"{round(total_dist / 1000, 1)} km",
        'elevation_min_m': int(min_ele) if min_ele != float('inf') else 0,
        'elevation_max_m': int(max_ele) if max_ele != float('-inf') else 0,
        'elevation_formatted': f"{int(min_ele) if min_ele != float('inf') else 0}m – {int(max_ele) if max_ele != float('-inf') else 0}m",
        'duration_seconds': duration,
        'duration_formatted': f"{h}h {m}m" if h > 0 else f"{m}m",
        'point_count': pt_count
    }

gpx_path = sys.argv[1]
output_file = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != '-' else None

try:
    result = parse_gpx(gpx_path)
    if output_file:
        with open(output_file, 'w') as f:
            json.dump(result, f, indent=2)
    else:
        print(json.dumps(result, indent=2))
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
EOF
}

parse_from_index() {
    local tracks_json="${1:-public/tracks.json}"
    
    if [[ ! -f "$tracks_json" ]]; then
        echo -e "${RED}Error: tracks.json not found: $tracks_json${NC}"
        exit 1
    fi
    
    # Get public folder path
    local public_dir=$(dirname "$tracks_json")
    
    echo -e "${CYAN}Parsing tracks from: $tracks_json${NC}"
    echo ""
    
    python3 - "$tracks_json" "$public_dir" << 'EOF'
import sys
import json
import xml.etree.ElementTree as ET
from datetime import datetime
import math

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    lat1_rad, lat2_rad = math.radians(lat1), math.radians(lat2)
    dlat, dlon = math.radians(lat2-lat1), math.radians(lon2-lon1)
    a = math.sin(dlat/2)**2 + math.cos(lat1_rad)*math.cos(lat2_rad)*math.sin(dlon/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

def parse_gpx(gpx_path):
    tree = ET.parse(gpx_path)
    root = tree.getroot()
    ns = {'gpx': 'http://www.topografix.com/GPX/1/1'}
    
    name = ""
    total_dist = 0.0
    min_ele, max_ele = float('inf'), float('-inf')
    start_time, end_time = None, None
    pt_count = 0
    
    metadata = root.find('gpx:metadata', ns)
    if metadata is not None:
        n = metadata.find('gpx:name', ns)
        if n is not None and n.text:
            name = n.text
    
    for track in root.findall('.//gpx:trk', ns):
        if not name:
            tn = track.find('gpx:name', ns)
            if tn is not None and tn.text:
                name = tn.text
        for seg in track.findall('gpx:trkseg', ns):
            pts = seg.findall('gpx:trkpt', ns)
            pt_count += len(pts)
            prev = None
            for pt in pts:
                lat, lon = float(pt.get('lat')), float(pt.get('lon'))
                ele_e = pt.find('gpx:ele', ns)
                ele = float(ele_e.text) if ele_e is not None and ele_e.text else 0.0
                time_e = pt.find('gpx:time', ns)
                time_str = time_e.text if time_e is not None else None
                min_ele, max_ele = min(min_ele, ele), max(max_ele, ele)
                if time_str:
                    try:
                        dt = datetime.fromisoformat(time_str.replace('Z', '+00:00'))
                        if not start_time: start_time = dt
                        end_time = dt
                    except: pass
                if prev: total_dist += haversine(prev[0], prev[1], lat, lon)
                prev = (lat, lon)
    
    duration = int((end_time - start_time).total_seconds()) if start_time and end_time else 0
    h, m = duration // 3600, (duration % 3600) // 60
    
    return {
        'name': name,
        'distance_km': round(total_dist / 1000, 1),
        'distance_formatted': f"{round(total_dist / 1000, 1)} km",
        'elevation_min_m': int(min_ele) if min_ele != float('inf') else 0,
        'elevation_max_m': int(max_ele) if max_ele != float('-inf') else 0,
        'elevation_formatted': f"{int(min_ele) if min_ele != float('inf') else 0}m – {int(max_ele) if max_ele != float('-inf') else 0}m",
        'duration_formatted': f"{h}h {m}m" if h > 0 else f"{m}m"
    }

tracks_json = sys.argv[1]
public_dir = sys.argv[2]

with open(tracks_json) as f:
    data = json.load(f)

results = []
for track in data.get('tracks', []):
    gpx_file = f"{public_dir}/{track['file']}"
    try:
        info = parse_gpx(gpx_file)
        info['id'] = track.get('id', track['file'])
        info['color'] = track.get('color', '#3b82f6')
        results.append(info)
        print(f"  \033[0;32m✓\033[0m {track['file']}: {info['distance_formatted']}, {info['elevation_formatted']}, {info['duration_formatted']}")
    except Exception as e:
        print(f"  \033[0;31m✗\033[0m {track['file']}: {e}")

# Save combined data
with open(f"{public_dir}/tracks-data.json", 'w') as f:
    json.dump({'tracks': results}, f, indent=2)
print(f"\n\033[0;32m✓\033[0m Saved to {public_dir}/tracks-data.json")
EOF
}

# Main
check_python

if [[ "$1" == "--from-index" ]]; then
    parse_from_index "${2:-public/tracks.json}"
elif [[ -n "$1" ]]; then
    if [[ ! -f "$1" ]]; then
        echo -e "${RED}Error: File not found: $1${NC}"
        exit 1
    fi
    parse_gpx "$1" "${2:--}"
else
    usage
fi