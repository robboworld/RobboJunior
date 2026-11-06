#!/usr/bin/env python3
"""latest.json: what the app reads to offer a new version (desktop/update-check.js).

Written next to the packages and uploaded after them, so the app never offers a file that is not there
yet. Downloads are relative to latest.json. The format is the one Robbo Scratch reads, without per-OS
versions: every upload carries all the packages of one version.

Usage: latest-json.py <release|alpha> <version> <date> <out-file> <package>...
"""

import json
import os
import sys

KINDS = {'.exe': 'windows', '.deb': 'deb', '.rpm': 'rpm'}


def main():
    if len(sys.argv) < 6 or sys.argv[1] not in ('release', 'alpha'):
        sys.exit(__doc__)
    channel, version, date, out_file = sys.argv[1:5]

    downloads = {}
    for package in sys.argv[5:]:
        name = os.path.basename(package)
        kind = KINDS.get(os.path.splitext(name)[1])
        if kind:
            downloads[kind] = name
    if not downloads:
        sys.exit('latest-json: нет пакетов')

    data = {
        'channel': channel,
        'version': version,
        'date': date,
        'important': False,
        'downloads': downloads,
        'notes': None,
    }
    with open(out_file, 'w', encoding='utf-8') as out:
        json.dump(data, out, ensure_ascii=False, indent=2)
        out.write('\n')


main()
