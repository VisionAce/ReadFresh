#!/usr/bin/env python3
"""ReadFresh 淡水召會晨興資料同步。預設 dry-run；--write 才更新 Firestore。"""
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


def check_existing(documents, incoming):
    """Return status and matching document IDs, never compare volatile date fields."""
    matches = [(doc_id, data) for doc_id, data in documents.items()
               if identity(data) == identity(incoming)]
    if not matches:
        return 'new', []
    if all(comparable(data) == comparable(incoming) for _, data in matches):
        return 'same', [doc_id for doc_id, _ in matches]
    raise ValueError('同一訓練與週次的內容不同，拒絕自動覆蓋，請人工確認。')


def validate_identity(data):
    if any(not value for value in identity(data)):
        raise ValueError('缺少訓練名稱、年份或週次，拒絕更新。')


def run_section(url=SOURCE_URL, fm=None, current_week=False, write=False):
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
    if fm is None:
        if not write and not (os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON') or os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')):
            print('DRY RUN: 已解析網站內容；未提供 Firebase 憑證，因此尚未比對資料庫。')
            return result
        from firebase import FirebaseManager
        fm = FirebaseManager()
    if not write:
        status, ids = check_existing(fm.get_all_documents('stg-data'), result)
        print(f'DRY RUN: Firestore comparison={status}; existing IDs={ids}; no writes.')
        return result
    status, version = fm.sync_tamsui(result, identity, comparable)
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
    args = parser.parse_args()
    try:
        run_section(url=args.url, current_week=args.current_week, write=args.write)
    except Exception as exc:
        print(f'ERROR: {type(exc).__name__}: {exc}', file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == '__main__':
    main()
