#!/usr/bin/env python3
"""«Что нового»: release-notes/<version>.{ru,en}.md → desktop/whats-new.json (see release-notes/README.md).

Usage: whats_new.py <current-version> <out-file>
"""

import glob
import json
import os
import re
import sys

NOTES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'release-notes')
SECTIONS = {
    'ru': {'новое': 'added', 'изменено': 'changed', 'исправлено': 'fixed'},
    'en': {'new': 'added', 'changed': 'changed', 'fixed': 'fixed'},
}
ITEM = re.compile(r'^- \*\*(\[Important\] )?(.+?):\*\* (.+)$')


class NotesError(Exception):
    pass


def version_key(version):
    match = re.match(r'^(\d+)\.(\d+)\.(\d+)(?:-(.+))?$', version)
    if not match:
        raise NotesError(f'версия {version!r} не вида X.Y.Z')
    suffix = match[4] or ''
    # X.Y.Z-N is a rebuild of X.Y.Z and goes after it, X.Y.Z-alpha goes before it
    stage = 1 if not suffix else (2 if suffix.isdigit() else 0)
    return (int(match[1]), int(match[2]), int(match[3]), stage, suffix.zfill(8) if stage == 2 else suffix)


def parse(path, language):
    name = os.path.basename(path)
    with open(path, encoding='utf-8') as source:
        lines = source.read().split('\n')
    if lines[0] != '---' or '---' not in lines[1:]:
        raise NotesError(f'{name}: нет заголовка ---')
    end = lines.index('---', 1)
    head = dict(line.split(':', 1) for line in lines[1:end] if ':' in line)

    note = {'version': head.get('version', '').strip(), 'date': head.get('date', '').strip(), 'intro': ''}
    note['sections'] = {key: [] for key in SECTIONS[language].values()}
    section = None
    for line in lines[end + 1:]:
        if not line.strip():
            continue
        if line.startswith('### '):
            section = SECTIONS[language].get(line[4:].strip().lower())
            if not section:
                raise NotesError(f'{name}: неизвестный раздел {line!r}')
        elif section is None:
            note['intro'] = (note['intro'] + ' ' + line.strip()).strip()
        else:
            item = ITEM.match(line)
            if not item:
                raise NotesError(f'{name}: строка не вида "- **Предмет:** текст": {line!r}')
            note['sections'][section].append({'important': bool(item[1]), 'title': item[2], 'text': item[3]})
    return note


def read_releases():
    releases = []
    for ru_path in glob.glob(os.path.join(NOTES_DIR, '*.ru.md')):
        file_version = os.path.basename(ru_path)[:-len('.ru.md')]
        en_path = ru_path[:-len('.ru.md')] + '.en.md'
        if not os.path.exists(en_path):
            raise NotesError(f'нет {os.path.basename(en_path)}')
        ru = parse(ru_path, 'ru')
        en = parse(en_path, 'en')
        if ru['version'] != file_version or en['version'] != file_version:
            raise NotesError(f'{file_version}: version в файле не совпадает с именем')
        for key, items in ru['sections'].items():
            other = en['sections'][key]
            if [i['important'] for i in items] != [i['important'] for i in other]:
                raise NotesError(f'{file_version}: разные пункты RU и EN в разделе {key}')
        important = any(i['important'] for items in ru['sections'].values() for i in items)
        releases.append({'version': file_version, 'date': ru['date'], 'important': important,
                         'ru': {k: ru[k] for k in ('intro', 'sections')},
                         'en': {k: en[k] for k in ('intro', 'sections')}})
    releases.sort(key=lambda release: version_key(release['version']), reverse=True)
    return releases


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    current, out_file = sys.argv[1:]
    try:
        releases = [r for r in read_releases() if version_key(r['version']) <= version_key(current)]
    except NotesError as error:
        sys.exit(f'Ошибка в release-notes: {error}')
    with open(out_file, 'w', encoding='utf-8') as out:
        json.dump({'current': current, 'releases': releases}, out, ensure_ascii=False)
        out.write('\n')


if __name__ == '__main__':
    main()
