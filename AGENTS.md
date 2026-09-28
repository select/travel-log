# Travel-Log Site Update Guide

Nuxt 4 static site showing cycling tours on a map with GPX routes and geotagged photos.

## Tour layout

- `public/tours.json` lists tours in display order as `{ "tours": [{ "id": "altmuehl2026", "name": "altmuehl2026" }, { "id": "vienna20216", "name": "vienna20216" }] }`. IDs are URL-safe folder names.
- Each tour has its own `public/tours/<id>/` folder containing `tracks.json`, `images.json`, GPX files, `images/` and `thumbnails/`. `tracks-data.json` is optional generated metadata.
- `vienna20216` is the Vienna trip; `altmuehl2026` has three day tracks and geotagged photos, and is the default.
- The map loads *only* the selected tour. `?tour=<id>` selects a tour; the first listed tour is the default.

## Adding photos to a tour

Source images on Termux: `/data/data/com.termux/files/home/storage/shared/dev/`.

```bash
./scripts/image-to-webp.sh /path/to/source-images public/tours/<id>
./scripts/generate-images-json.sh /path/to/source-images public/tours/<id>/images.json
# For photos without GPS, infer coordinates from EXIF time and timed GPX points
python3 scripts/locate-images-from-gpx.py public/tours/<id>
```

The converter creates `images/*.webp` (max 2048px, quality 85) and `thumbnails/*.webp` (300x300, quality 80), skipping files with both outputs. The metadata script preserves existing JSON entries and uses exiftool or Python Pillow on the source JPGs for GPS/time. Photo `file` entries are basenames inside the tour's `images/` directory. The GPX locator interprets photo times as Europe/Berlin local time by default (`--timezone` overrides this), preserves camera GPS and marks inferred entries with `location_source: "gpx-estimate"`. It interpolates within short GPX gaps and snaps to the closest track point otherwise, up to 10 minutes away.

## Adding GPX tracks

Source GPX files on Termux: `/data/data/com.termux/files/home/downloads/`.

```bash
cp /path/to/track.gpx public/tours/<id>/
# Add a track entry to public/tours/<id>/tracks.json
./scripts/extract-gpx-data.sh --from-index public/tours/<id>/tracks.json
```

Track entries have `id`, `name`, `file` (basename of GPX in that tour folder) and `color`. Distinct suggested colors: blue `#3b82f6`, red `#ef4444`, green `#22c55e`, orange `#f97316`, purple `#a855f7`. The extraction script writes `tracks-data.json` next to the index.

## Adding a tour

Create `public/tours/<id>/tracks.json` (`{"tracks":[]}`) and `images.json` (`[]`), then add `{ "id": "<id>", "name": "Display name" }` to `public/tours.json`. Put only this tour's GPX files and converted images in its folder. Use the commands above with its path, not the default `altmuehl2026` path.

## Build & deploy

```bash
pnpm dev
pnpm build
pnpm preview
```

The user runs `pnpm preview` themselves before deploying. Build may take 2–5 minutes on mobile. Do not commit or push without request.
