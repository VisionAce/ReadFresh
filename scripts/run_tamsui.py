#!/usr/bin/env python3
"""ReadFresh 淡水召會晨興資料同步：比對最新版本，內容不同即追加新版本。"""
import argparse
import datetime
import json
import os
import re
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

from bs4 import BeautifulSoup, NavigableString
from curl_cffi import requests

SOURCE_URL = 'https://churchintamsui.wixsite.com/index/morning-revival'
DB_VERSION = '1'
TAIPEI_TZ = ZoneInfo('Asia/Taipei')
WEEK = r'第[零〇一二三四五六七八九十百兩\d]+週'
# 年份支援阿拉伯數字及中文數字（含 ○、〇、零、Ｏ）。
YEAR_TOKEN = r'(?:20\d{2}|[二兩貳贰２2][零〇○Ｏ０0][二兩貳贰２2][零〇○Ｏ０0一二三四五六七八九１２３４５６７８９0-9])'
YEAR_PREFIX = rf'(?P<year>{YEAR_TOKEN})\s*年?\s*[,，、．.：:－-]?\s*'
TRAINING_TITLE = re.compile(
    rf'^{YEAR_PREFIX}(?P<name>.+?)\s*[『「](?P<topic>[^』」]+)[』」]\s*$'
)
TRAINING_NAME_ONLY = re.compile(
    rf'^{YEAR_PREFIX}(?P<name>.+?(?:訓練|特會|相調|聚會))\s*$'
)
YEAR_DIGITS = str.maketrans({
    '零': '0', '〇': '0', '○': '0', 'Ｏ': '0', '０': '0',
    '一': '1', '壹': '1', '１': '1', '二': '2', '兩': '2', '貳': '2', '贰': '2', '２': '2',
    '三': '3', '３': '3', '四': '4', '４': '4', '五': '5', '５': '5',
    '六': '6', '６': '6', '七': '7', '７': '7', '八': '8', '８': '8',
    '九': '9', '９': '9',
})


def normalize_year(value):
    year = value.translate(YEAR_DIGITS)
    if not re.fullmatch(r'20\d{2}', year):
        raise ValueError(f'無法辨識訓練年份：{value!r}')
    return year


def normalize_training_name(value):
    # 保留名稱內有意義的標點，只去除網站排版造成的多餘空白。
    return clean_text(value).strip(' 、，,')


def normalize_topic(value):
    return clean_text(value).strip('『』「」 ')


OUTLINE_TITLE = re.compile(rf'^({WEEK})\s*[：:、，,•．·■\s]+\s*(.+)$')
DAY_TITLE = re.compile(rf'^({WEEK})\s*[•．·■]\s*(週[一二三四五六])$')
DAYS = [f'週{day}' for day in '一二三四五六']
IDENTITY_FIELDS = ('training_year', 'training_name', 'section_number')
CONTENT_FIELDS = ('training_year', 'training_name', 'training_topic', 'type',
                  'section_number', 'section_name', 'outline', 'day_messages')


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
    # Wix 會把標點拆成獨立文字節點，例如「第一週」「、」「篇名」
    # 或「壹」「、」「綱目」。重新接合，以保留既有 Firestore 文字格式。
    merged = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line in {'、', '，', ',', '：', ':'} and merged and i + 1 < len(lines):
            merged[-1] += line + lines[i + 1]
            i += 2
            continue
        merged.append(line)
        i += 1
    return merged


class TamsuiParser:
    def __init__(self, html):
        self.soup = BeautifulSoup(html, 'html.parser')

    def run(self):
        # 網站新主題可能改用 h1/h3、不同引號，或將主題另起一行。
        # 僅在同一個 wixui-rich-text 正文區塊中尋找標題，避免抓到導覽列。
        candidates = []
        for body in self.soup.select('.wixui-rich-text'):
            for tag in body.find_all(['h1', 'h2', 'h3', 'h4', 'p']):
                value = clean_text(tag.get_text(' ', strip=True))
                match = TRAINING_TITLE.fullmatch(value)
                if match:
                    candidates.append((body, normalize_year(match.group('year')),
                                       normalize_training_name(match.group('name')),
                                       normalize_topic(match.group('topic'))))
        if not candidates:
            # 允許沒有書名號的訓練標題；主題需在相鄰標題文字中明確提供。
            for body in self.soup.select('.wixui-rich-text'):
                headings = [
                    clean_text(t.get_text(' ', strip=True))
                    for t in body.find_all(['h1', 'h2', 'h3', 'h4', 'p'])
                ]
                for i, value in enumerate(headings):
                    match = TRAINING_NAME_ONLY.fullmatch(value)
                    if not match:
                        continue
                    nearby = headings[i + 1:i + 4]
                    topic = next(
                        (t.strip('『』「」 ') for t in nearby
                         if t.startswith(('主題：', '主題:', '『', '「'))),
                        ''
                    )
                    if topic.startswith(('主題：', '主題:')):
                        topic = re.split(r'[：:]', topic, maxsplit=1)[-1].strip()
                    if topic:
                        candidates.append((body, normalize_year(match.group('year')),
                                           normalize_training_name(match.group('name')),
                                           normalize_topic(topic)))
        if not candidates:
            sample = [
                clean_text(t.get_text(' ', strip=True))
                for t in self.soup.find_all(['h1', 'h2', 'h3'])
            ]
            raise ValueError(
                '找不到符合格式的訓練標題。網站可能使用新的標題格式。'
                f' 候選標題（前 12 筆）：{sample[:12]!r}'
            )
        # 優先選擇具有完整週一至週六資料的正文區塊。
        body, year, name, topic = next(
            ((b, y, n, t) for b, y, n, t in candidates
             if any(OUTLINE_TITLE.fullmatch(line) for line in content_lines(b))),
            candidates[0]
        )
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


def identity(data):
    return tuple(clean_text(str(data.get(key, ''))) for key in IDENTITY_FIELDS)


def comparable(data):
    return {key: data.get(key) for key in CONTENT_FIELDS}


def validate_identity(data):
    if any(not value for value in identity(data)):
        raise ValueError('缺少訓練名稱、年份或週次，拒絕更新。')


def check_latest(latest_id, latest_data, incoming):
    return ('same' if comparable(latest_data) == comparable(incoming) else 'changed', latest_id)


def week_number(week_text):
    """把第十二週、第13週等週次轉成整數；不支援時回傳 None。"""
    match = re.fullmatch(r'第(.+)週', clean_text(week_text))
    if not match:
        return None
    token = match.group(1)
    if token.isdecimal():
        return int(token)
    numerals = {'零': 0, '〇': 0, '一': 1, '二': 2, '兩': 2, '三': 3,
                '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9}
    if '百' in token:
        left, _, right = token.partition('百')
        hundreds = numerals.get(left, 1) if left else 1
        if hundreds is None:
            return None
        suffix = week_number('第' + right + '週') if right else 0
        return hundreds * 100 + suffix if suffix is not None else None
    if '十' in token:
        left, _, right = token.partition('十')
        tens = numerals.get(left, 1) if left else 1
        ones = numerals.get(right) if right else 0
        return tens * 10 + ones if tens is not None and ones is not None else None
    return numerals.get(token)


def calculate_week_dates(now=None, current_week=False):
    """新週次：週日使用下週，其餘使用本週；日期以台灣時區計算。"""
    now = now or datetime.datetime.now(TAIPEI_TZ)
    if now.tzinfo is None or now.utcoffset() is None:
        raise ValueError('now 必須是具有時區的 datetime')
    local_now = now.astimezone(TAIPEI_TZ)
    monday = local_now.date() - datetime.timedelta(days=local_now.weekday())
    if local_now.weekday() == 6 and not current_week:
        monday += datetime.timedelta(days=7)
    start = datetime.datetime.combine(monday, datetime.time.min, tzinfo=TAIPEI_TZ)
    return start, start + datetime.timedelta(days=7)


def resolve_week_dates(incoming, latest_data, now=None, current_week=False):
    """同一訓練週次沿用既有週期；新週次依台灣日期計算。"""
    if latest_data and identity(incoming) == identity(latest_data):
        start, end = latest_data.get('started_day'), latest_data.get('ended_day')
        if not isinstance(start, datetime.datetime) or not isinstance(end, datetime.datetime):
            raise ValueError('最新同週版本缺少有效 started_day / ended_day，拒絕猜測日期。')
        if start.tzinfo is None or end.tzinfo is None or end <= start:
            raise ValueError('最新同週版本的日期不正確，拒絕新增。')
        return start, end, 'reuse-latest-week'

    if latest_data:
        # 同一訓練內，週次回退或無法判斷時，不應自動套用當週日期。
        same_training = (str(incoming.get('training_year')) == str(latest_data.get('training_year'))
                         and clean_text(str(incoming.get('training_name'))) ==
                         clean_text(str(latest_data.get('training_name'))))
        if same_training:
            old_number = week_number(str(latest_data.get('section_number', '')))
            new_number = week_number(str(incoming.get('section_number', '')))
            if old_number is None or new_number is None or new_number <= old_number:
                raise ValueError('網站週次回退或無法辨識，無法安全推定日期；請人工確認。')

    start, end = calculate_week_dates(now, current_week)
    return start, end, 'new-week-taipei'


def firebase_json(data):
    def encode(obj):
        if isinstance(obj, (datetime.datetime, datetime.date)):
            return obj.isoformat()
        raise TypeError(f'Unsupported type: {type(obj).__name__}')
    return json.dumps(data, ensure_ascii=False, indent=2, default=encode)


def print_readable(data):
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
            path = Path(export_json).expanduser()
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(payload + '\n', encoding='utf-8')
            print(f'JSON 已匯出：{path.resolve()}')


def run_section(url=SOURCE_URL, fm=None, current_week=False, write=False,
                show_readable=True, show_json=False, export_json=None, now=None):
    response = requests.get(url, impersonate='chrome', timeout=60)
    response.raise_for_status()
    result = TamsuiParser(response.text).run()
    validate_identity(result)
    now = now or datetime.datetime.now(TAIPEI_TZ)
    print('Parsed:', json.dumps({key: result[key] for key in IDENTITY_FIELDS}, ensure_ascii=False))

    latest_id, latest_data = None, None
    if fm is None:
        if write or os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON') or os.environ.get('GOOGLE_APPLICATION_CREDENTIALS'):
            from firebase import FirebaseManager
            fm = FirebaseManager()
    if fm is not None:
        latest_id, latest_data = fm.get_latest_section()

    # 無憑證時可以預覽，但無法得知是否為同週修正，因此不能保證日期準確。
    if latest_data is None:
        if write:
            raise RuntimeError('正式寫入需要先讀取 Firestore 最新版本。')
        start, end = calculate_week_dates(now, current_week)
        date_source = 'estimated-without-firestore'
    else:
        start, end, date_source = resolve_week_dates(result, latest_data, now, current_week)

    result.update({'started_day': start, 'ended_day': end,
                   'created_day': now, 'db_version': DB_VERSION})
    print(f'Date rule: {date_source}; started_day={start.isoformat()}; ended_day={end.isoformat()}')
    preview_payload(result, show_readable, show_json, export_json)

    if fm is None:
        print('DRY RUN: 已解析網站內容；未提供 Firebase 憑證，因此尚未比對資料庫。')
        return result
    if not write:
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
    parser.add_argument('--current-week', action='store_true', help='新週次也強制使用本週台灣日期（預設週日用下週）')
    parser.add_argument('--url', default=SOURCE_URL)
    parser.add_argument('--show-json', action='store_true', help='終端機顯示完整 Firestore JSON')
    parser.add_argument('--export-json', metavar='PATH', help='將完整 Firestore JSON 儲存至指定檔案')
    parser.add_argument('--no-preview', action='store_true', help='關閉人類易讀內容預覽（適合排程）')
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
