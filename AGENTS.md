# Travel-Log Site Update Guide

## Overview

The travel-log is a Nuxt 4 static site that displays cycling routes on an interactive map with photo markers. GPX tracks and images are processed through scripts to generate the data files used by the web app.

---

## File Locations

```
travel-log/
├── public/
│   ├── 2026-part-1.gpx          # GPX track files
│   ├── 2026-part-2.gpx
│   ├── 2026-part-3.gpx
│   ├── tracks.json               # GPX index (tracks to display)
│   ├── tracks-data.json          # Extracted GPX metadata (auto-generated)
│   ├── images.json               # Image GPS metadata (auto-generated)
│   ├── images/                   # Full-size WebP photos
│   └── thumbnails/               # 300x300 WebP thumbnails
└── scripts/
    ├── image-to-webp.sh          # Convert images to WebP
    ├── generate-images-json.sh  # Extract GPS from source JPGs
    ├── extract-gpx-data.sh      # Parse GPX files
    └── extract-image-metadata.sh
```

**Source images location:** `/data/data/com.termux/files/home/storage/shared/dev/`

**Source GPX location:** `/data/data/com.termux/files/home/downloads/`

---

## Order of Operations

### 1. Add New Images

```bash
# Convert new JPG images to WebP (full + thumbnail)
# Skips already converted images
./scripts/image-to-webp.sh /data/data/com.termux/files/home/storage/shared/dev public
```

**What it does:**
- Reads all JPG/JPEG/PNG from source directory
- Converts to WebP (max 2048px, quality 85)
- Creates 300x300 square thumbnails (quality 80)
- Skips files that already have both webp outputs

**Output:**
- `public/images/[name].webp`
- `public/thumbnails/[name].webp`

---

### 2. Update Image GPS Data

```bash
# Extract GPS coordinates from source JPGs into images.json
# Preserves existing entries, adds new ones
./scripts/generate-images-json.sh
```

**What it does:**
- Loads existing `public/images.json`
- For each webp in `public/images/`, finds corresponding source JPG
- Extracts GPS Latitude, GPS Longitude, DateTimeOriginal via exiftool
- Saves combined JSON (sorted by filename)

**Source image matching:**
- Looks for `/data/data/com.termux/files/home/storage/shared/dev/[name].jpg`
- Falls back to `.JPG` extension

**Output:** `public/images.json`

---

### 3. Add New GPX Track

```bash
# 1. Copy GPX file to public folder
cp /path/to/new-track.gpx public/

# 2. Edit tracks.json to register the new track
# The color is set per-track, site reads from tracks.json dynamically

# 3. Extract track metadata
./scripts/extract-gpx-data.sh --from-index
```

**Color assignment:** Each track in `tracks.json` has its own color. The site dynamically reads `tracks.json` to load all tracks. Pick a color not already used.

**Available colors:** Blue `#3b82f6`, Red `#ef4444`, Green `#22c55e`, Orange `#f97316`, Purple `#a855f7`

**tracks.json format:**
```json
{
  "tracks": [
    {
      "id": "part-1",
      "name": "From Britz to Vienna",
      "file": "2026-part-1.gpx",
      "color": "#3b82f6"
    },
    {
      "id": "part-2",
      "name": "From Hindenberg to Vienna",
      "file": "2026-part-2.gpx",
      "color": "#ef4444"
    }
  ]
}
```

**Color options:** Blue `#3b82f6`, Red `#ef4444`, Green `#22c55e`, Orange `#f97316`, Purple `#a855f7`

---

### 4. Extract GPX Metadata

```bash
# Parse all tracks in tracks.json and generate tracks-data.json
./scripts/extract-gpx-data.sh --from-index
```

**What it extracts:**
- Track name
- Total distance (km)
- Elevation range (min/max meters)
- Duration (formatted as "Xh Ym" or "Ym")
- Point count

**Output:** `public/tracks-data.json`

---

## Script Reference

### image-to-webp.sh

```bash
./scripts/image-to-webp.sh <source_dir> [output_dir]
```

- **source_dir:** Directory containing source JPG images
- **output_dir:** Target directory (default: `public`)
- **Skips:** Files with existing webp + thumbnail
- **Progress:** Shows [n/total] with sizes
- **Timeout:** Can take 2-5 minutes per image on mobile devices

### generate-images-json.sh

```bash
./scripts/generate-images-json.sh [source_dir] [output_json]
```

- **source_dir:** Directory with source JPGs (default: `/data/data/com.termux/files/home/storage/shared/dev`)
- **output_json:** Output JSON file (default: `public/images.json`)
- **Extends:** Preserves existing entries, only adds new webp files
- **Requires:** exiftool installed

### extract-gpx-data.sh

```bash
# Single GPX
./scripts/extract-gpx-data.sh <gpx_file> [output_json]

# All tracks from index
./scripts/extract-gpx-data.sh --from-index [tracks.json]
```

- **--from-index:** Reads `tracks.json`, outputs `tracks-data.json`
- **Outputs to stdout** if no output file specified
- **Timeout:** Usually fast (~10s for 6 tracks)

---

## Build & Deploy

```bash
# Development
pnpm dev

# Production build
pnpm build

# Preview production build
pnpm preview

# Deploy (GitHub Actions)
git add .
git commit -m "Update: new images and track"
git push
```

**Note:** `pnpm build` can take 2-5 minutes on mobile devices. Use longer timeout if running programmatically.

**Preview:** User runs `pnpm preview` themselves to test before deploying.

---

## Data Flow

```
Source Images (storage/shared/dev/*.jpg)
    │
    ▼
image-to-webp.sh ──────────────────► public/images/*.webp
    │                                public/thumbnails/*.webp
    │
    ▼
generate-images-json.sh ──────────► public/images.json
    │
Source GPX (downloads/*.gpx)
    │
    ▼
Copy to public/*.gpx ─────────────► public/*.gpx
    │
    ▼
Edit tracks.json
    │
    ▼
extract-gpx-data.sh --from-index ──► public/tracks-data.json
```

---

## Adding New Trip Day

1. **Images:**
   ```bash
   ./scripts/image-to-webp.sh /data/data/com.termux/files/home/storage/shared/dev public
   ./scripts/generate-images-json.sh
   ```

2. **GPX:**
   ```bash
   cp /path/to/2026-part-4.gpx public/
   # Add to tracks.json manually
   ./scripts/extract-gpx-data.sh --from-index
   ```

3. **Build & deploy:**
   ```bash
   pnpm build
   git add . && git commit -m "Add part 4" && git push
   ```

---

## Troubleshooting

**Script segfaults:** Some tools have issues on Termux. Try running scripts individually.

**Missing GPS:** Check source JPG has location data enabled in camera settings.

**Tracks not showing:** Verify `tracks.json` has correct filename matching the GPX in public/.

**Images not loading:** Check `images.json` has matching filenames to webp files in public/images/.