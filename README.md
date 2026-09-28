# Travel log

Nuxt static site for cycling tours, GPX routes and geotagged photos.

## Tours

Each tour lives in its own folder under `public/tours/<id>/`:

```text
public/tours.json                 # tour selector: [{ "id": "altmuehl2026", "name": "altmuehl2026" }, ...]
public/tours/vienna20216/
  tracks.json                    # { "tracks": [{ "id", "name", "file", "color" }, ...] }
  *.gpx
  tracks-data.json               # optional generated track metadata
  images.json                    # [{ "file", "lat", "lon", "date" }, ...]
  images/*.webp
  thumbnails/*.webp
```

`vienna20216` contains the Vienna trip; `altmuehl2026` contains the three Altmühltal day tracks and photos, and is the default. Tour IDs should be URL-safe folder names. The selected tour is shareable via `?tour=<id>`; without a query the first listed tour is shown.

To add another tour, create `public/tours/<id>/tracks.json` with `{"tracks":[]}` and `images.json` with `[]`, then register it in `public/tours.json`. Put GPX files and converted images in that tour's folder and add their metadata to its JSON files. Track `file` values and photo `file` values are filenames relative to that tour's folder and `images/` respectively.

```bash
# Convert source photos into one tour's images/ and thumbnails/
./scripts/image-to-webp.sh /path/to/source-photos public/tours/<id>
# Generate GPS metadata from those source photos; preserves existing entries
./scripts/generate-images-json.sh /path/to/source-photos public/tours/<id>/images.json
# Estimate missing GPS from EXIF timestamps and GPX tracks (local time defaults to Europe/Berlin)
python3 scripts/locate-images-from-gpx.py public/tours/<id>
# Generate optional GPX summary after adding files to tracks.json
./scripts/extract-gpx-data.sh --from-index public/tours/<id>/tracks.json

pnpm install
pnpm dev
pnpm build
```

The metadata scripts default to the `altmuehl2026` tour when no output/index argument is supplied. `generate-images-json.sh` requires exiftool or Python Pillow; image conversion requires ImageMagick or cwebp. The GPX locator preserves camera GPS, interpolates between nearby timed GPX points, and snaps to the nearest track point where interpolation is not possible (within 10 minutes); estimated entries are marked `location_source: "gpx-estimate"`.
