#!/usr/bin/env python3
"""Estimate GPS for unlocated tour photos from their local EXIF time and GPX tracks.

Usage: python3 scripts/locate-images-from-gpx.py public/tours/<id>
Only entries without GPS are updated. Existing camera GPS coordinates are preserved.
"""

import argparse
from bisect import bisect_left
from datetime import datetime, timezone
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from zoneinfo import ZoneInfo


def gps_string(value: float, latitude: bool) -> str:
    direction = ('N' if value >= 0 else 'S') if latitude else ('E' if value >= 0 else 'W')
    degrees = int(abs(value))
    minutes_full = (abs(value) - degrees) * 60
    minutes = int(minutes_full)
    seconds = (minutes_full - minutes) * 60
    return f'{degrees} deg {minutes}\' {seconds:.6f}" {direction}'


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tour_dir', type=Path)
    parser.add_argument('--timezone', default='Europe/Berlin', help='Timezone of the photo EXIF timestamps')
    args = parser.parse_args()

    with (args.tour_dir / 'tracks.json').open() as file:
        tracks = json.load(file)['tracks']
    with (args.tour_dir / 'images.json').open() as file:
        photos = json.load(file)

    # (timestamp UTC, latitude, longitude, track ID)
    points = []
    for track in tracks:
        root = ET.parse(args.tour_dir / track['file']).getroot()
        for element in root.iter():
            if element.tag.rsplit('}', 1)[-1] != 'trkpt':
                continue
            timestamp = next((child.text for child in element if child.tag.rsplit('}', 1)[-1] == 'time'), None)
            if timestamp:
                recorded = datetime.fromisoformat(timestamp.replace('Z', '+00:00')).astimezone(timezone.utc)
                points.append((recorded, float(element.attrib['lat']), float(element.attrib['lon']), track['id']))
    if not points:
        raise ValueError('No timestamped GPX points available')
    points.sort()
    times = [point[0] for point in points]
    local_tz = ZoneInfo(args.timezone)

    located = 0
    unresolved = []
    for photo in photos:
        if photo.get('lat') and photo.get('lon'):
            continue
        try:
            taken = datetime.strptime(photo['date'], '%Y:%m:%d %H:%M:%S').replace(tzinfo=local_tz).astimezone(timezone.utc)
        except (KeyError, ValueError):
            unresolved.append(photo['file'])
            continue
        index = bisect_left(times, taken)
        neighbors = [i for i in (index - 1, index) if 0 <= i < len(points)]
        nearest = min(neighbors, key=lambda i: abs((times[i] - taken).total_seconds()))
        gap = abs((times[nearest] - taken).total_seconds())
        if gap > 600:  # A distant track day is not a meaningful location estimate.
            unresolved.append(photo['file'])
            continue

        lat, lon = points[nearest][1:3]
        method = 'nearest point'
        if 0 < index < len(points):
            before, after = points[index - 1], points[index]
            span = (after[0] - before[0]).total_seconds()
            if before[3] == after[3] and 0 < span <= 300:
                fraction = (taken - before[0]).total_seconds() / span
                lat = before[1] + fraction * (after[1] - before[1])
                lon = before[2] + fraction * (after[2] - before[2])
                method = 'interpolated'

        photo['lat'] = gps_string(lat, True)
        photo['lon'] = gps_string(lon, False)
        photo['location_source'] = 'gpx-estimate'
        located += 1
        print(f"{photo['file']}: {method} (nearest point {gap:.0f}s away)")

    with (args.tour_dir / 'images.json').open('w') as file:
        json.dump(photos, file, indent=2, ensure_ascii=False)
        file.write('\n')
    print(f'Located {located} photos; {len(unresolved)} unresolved')
    if unresolved:
        print('Unresolved:', ', '.join(unresolved))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
