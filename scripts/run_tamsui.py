#!/usr/bin/env python3
"""ReadFresh 淡水召會晨興資料同步。只比較目前版本，內容不同就追加新版本。"""
import argparse
import datetime
import json
import os
import re
import sys
from bs4 import BeautifulSoup, NavigableString
from curl_cffi import requests

SOURCE_URL = 'https://churchintamsui.wixsite.com/index/morning-revival'
DB_VERSION = '1'
WEEK = r'第[零〇一二三四五六七八九十百兩\d]+週'
TRAINING_TITLE = re.compile(r'^(\d{4})\s*年\s*(.+?)\s*『(.+?)』$')
OUTLINE_TITLE = re.compile(rf'^({WEEK})\s*[：:　 ]\s*(.+)$')
DAY_TITLE = re.compile(rf'^({WEEK})\s*[•．·■]\s*(週[一二三四五六])$')
DAYS = [f'週{day}' for day in '一二三四五六']


def clean_text(text):
    return re.sub(r'\s+', ' ', text.replace('\u200b', '').replace('\ufeff', '')).strip()


def content_lines(root):
    lines, pending = [], []
    def flush():
        line = clean_text(''.join(pending))
        pending.clear()
        if line:
            lines.append(line)
    def walk(node):
        if isinstance(node, NavigableString):
            pending.append(str(node))
            return
        if node.name in {'script', 'style'}:
            return
        if node.name == 'br':
            flush()
            return
        if node.name in {'ol', 'ul'}:
            flush()
            number = int(node.get('start', 1))
            for item in node.find_all('li', recursive=False):
                number = int(item.get('value', number))
                first_line = len(lines)
                walk(item)
                flush()
                if len(lines) > first_line:
                    marker = f'{number}. ' if node.name == 'ol' else '• '
                    lines[first_line] = marker + lines[first_line]
                number += 1
            return
        block = node.name in {'p', 'div', 'li', 'h1', 'h2', 'h3', 'h4'}
        if block:
            flush()
        for child in node.children:
            walk(child)
        if block:
            flush()
    walk(root)
    flush()
    return lines


class TamsuiParser:
    def __init__(self, html):
        self.soup = BeautifulSoup(html, 'html.parser')

    def run(self):
        title = next((tag for tag in self.soup.find_all('h2')
                      if TRAINING_TITLE.fullmatch(clean_text(tag.get_text()))), None)
        if title is None:
            raise ValueError('找不到特會年份、名稱與主題。')
        body = title.find_parent(class_='wixui-rich-text')
        if body is None:
            raise ValueError('找不到淡水召會的正文區塊。')
        year, name, topic = TRAINING_TITLE.fullmatch(clean_text(title.get_text())).groups()
        lines = content_lines(body)
        outline_start = next((i for i, line in enumerate(lines)
                              if OUTLINE_TITLE.fullmatch(line)), None)
        if outline_start is None:
            raise ValueError('找不到週次與綱目標題。')
        week, section_name = OUTLINE_TITLE.fullmatch(lines[outline_start]).groups()
        headings = [(i, match) for i, line in enumerate(lines)
                    if (match := DAY_TITLE.fullmatch(line))]
        if [match.group(2) for _, match in headings] != DAYS:
            raise ValueError('每日信息必須依序包含週一至週六，且不得重複。')
        if any(match.group(1) != week for _, match in headings):
            raise ValueError('每日信息週次與綱目不一致。')
        if headings[0][0] <= outline_start:
            raise ValueError('綱目與每日信息的順序不正確。')
        outline = lines[outline_start:headings[0][0]]
        if not any(line.startswith('讀經') for line in outline):
            raise ValueError('綱目缺少讀經內容。')
        if not any(re.match(r'[壹貳贰參叁肆伍陸陆柒捌玖拾]、', line) for line in outline):
            raise ValueError('綱目缺少主要段落。')
        outline = [re.sub(r'[【〖]\s*週\s*([一二三四五六])\s*[】〗]', r'週\1', line)
                   for line in outline]
        messages = []
        for day_index, (start, match) in enumerate(headings):
            end = headings[day_index + 1][0] if day_index < 5 else len(lines)
            context = lines[start:end]
            for marker in ('晨興餧養', '信息選讀'):
                if context.count(marker) != 1:
                    raise ValueError(f'{match.group(2)} 缺少或重複「{marker}」。')
            feeding, reading = context.index('晨興餧養'), context.index('信息選讀')
            if not (feeding + 1 < reading < len(context) - 1):
                raise ValueError(f'{match.group(2)} 的晨興餧養或信息選讀內容不完整。')
            messages.append({'week': week, 'day': match.group(2), 'type': 'DayMessage',
                             'data': [{'context': context, 'page': '1'}]})
        return {'training_year': year, 'training_name': name.strip(),
                'training_topic': topic.strip(), 'type': 'Training',
                'section_number': week, 'section_name': section_name,
                'outline': [{'context': outline, 'page': '1'}],
                'day_messages': messages}


IDENTITY_FIELDS = ('training_year', 'training_name', 'section_number')
CONTENT_FIELDS = ('training_year', 'training_name', 'training_topic', 'type',
                  'section_number', 'section_name', 'outline', 'day_messages')


def identity(data):
    return tuple(clean_text(str(data.get(key, ''))) for key in IDENTITY_FIELDS)


def comparable(data):
    return {key: data.get(key) for key in CONTENT_FIELDS}


def check_latest(latest_id, latest_data, incoming):
    """Compare only the current version's substantive content.

    Historical documents are immutable and intentionally ignored. A correction to
    the same week becomes a new version; a return to older content also becomes
    a new version if the current version differs.
    """
    if comparable(latest_data) == comparable(incoming):
        return 'same', latest_id
    return 'changed', latest_id


def validate_identity(data):
    if any(not value for value in identity(data)):
        raise ValueError('缺少訓練名稱、年份或週次，拒絕更新。')


def firebase_json(data):
    """JSON-friendly view of the Firestore payload (timestamps in ISO 8601)."""
    return json.dumps(data, ensure_ascii=False, indent=2, default=lambda obj:
                      obj.isoformat() if isinstance(obj, (datetime.datetime, datetime.date))
                      else (_ for _ in ()).throw(TypeError(f'Unsupported type: {type(obj).__name__}')))


def print_readable(data):
    """Print the parsed content without altering what is written to Firestore."""
    print('\n' + '=' * 64)
    print('晨興聖言｜網頁解析預覽')
    print('=' * 64)
    for key, label in (('training_year', '年份'), ('training_name', '訓練'),
                       ('training_topic', '主題'), ('section_number', '週次'),
                       ('section_name', '篇名')):
        print(f'{label}：{data.get(key, "")}')
    print('\n【綱目】')
    for item in data.get('outline', []):
        for line in item.get('context', []):
            print(line)
    for item in data.get('day_messages', []):
        print(f'\n【{item.get("day", "每日信息")}】')
        for page in item.get('data', []):
            for line in page.get('context', []):
                print(line)
    print('\n【Firestore 欄位】')
    for key in ('started_day', 'ended_day', 'created_day', 'db_version'):
        value = data.get(key)
        print(f'{key}: {value.isoformat() if isinstance(value, datetime.datetime) else value}')
    print('=' * 64 + '\n')


def preview_payload(data, show_readable=False, show_json=False, export_json=None):
    if show_readable:
        print_readable(data)
    if show_json or export_json:
        payload = firebase_json(data)
        if show_json:
            print('\n【完整 Firestore JSON 預覽】\n' + payload)
        if export_json:
            from pathlib import Path
            path = Path(export_json).expanduser()
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(payload + '\n', encoding='utf-8')
            print(f'JSON 已匯出：{path.resolve()}')


def run_section(url=SOURCE_URL, fm=None, current_week=False, write=False,
                show_readable=True, show_json=False, export_json=None):
    response = requests.get(url, impersonate='chrome', timeout=60)
    response.raise_for_status()
    result = TamsuiParser(response.text).run()
    now = datetime.datetime.now(datetime.timezone.utc)
    started_day = (now - datetime.timedelta(days=now.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0)
    if not current_week:
        started_day += datetime.timedelta(days=7)
    result.update({'started_day': started_day,
                   'ended_day': started_day + datetime.timedelta(days=7),
                   'created_day': now, 'db_version': DB_VERSION})
    print('Parsed:', json.dumps({key: result[key] for key in IDENTITY_FIELDS}, ensure_ascii=False))
    validate_identity(result)
    preview_payload(result, show_readable, show_json, export_json)
    if fm is None:
        if not write and not (os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON') or os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')):
            print('DRY RUN: 已解析網站內容；未提供 Firebase 憑證，因此尚未比對資料庫。')
            return result
        from firebase import FirebaseManager
        fm = FirebaseManager()
    if not write:
        latest_id, latest_data = fm.get_latest_section()
        status, previous_id = check_latest(latest_id, latest_data, result)
        print(f'DRY RUN: Firestore comparison={status}; latest ID={previous_id}; no writes.')
        return result
    status, version = fm.sync_tamsui(result, comparable)
    if status == 'skipped':
        print(f'SKIP: existing stg-data/{version}; metadata unchanged')
    else:
        print(f'CREATED: stg-data/{version}; metadata version={version}')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='正式寫入 Firebase（預設不寫入）')
    parser.add_argument('--current-week', action='store_true', help='沿用本週 UTC 日期（預設下週）')
    parser.add_argument('--url', default=SOURCE_URL)
    parser.add_argument('--show-json', action='store_true', help='終端機顯示完整 Firestore JSON')
    parser.add_argument('--export-json', metavar='PATH', help='將完整 Firestore JSON 儲存至指定檔案')
    parser.add_argument('--no-preview', action='store_true', help='關閉預設的人類易讀內容預覽（適合排程）')
    args = parser.parse_args()
    try:
        run_section(url=args.url, current_week=args.current_week, write=args.write,
                    show_readable=not args.no_preview, show_json=args.show_json,
                    export_json=args.export_json)
    except Exception as exc:
        print(f'ERROR: {type(exc).__name__}: {exc}', file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == '__main__':
    main()
