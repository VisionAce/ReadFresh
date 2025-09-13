#!/usr/bin/python3

import pandas as pd
import string
import requests
import datetime
import random
import re
from bs4 import BeautifulSoup
from firebase import FirebaseManager

# Update DB version if database structure changed
DB_VERSION = "1"

TOP_INDEX = ['壹', '贰', '叁', '肆', '伍',  '陆',  '柒',
    '捌', '玖', '拾'
]

SECOND_INDEX = ['一', '二', '三', '四', '五', '六', '七', '八', '九',
    '十', '十一', '十二', '十三', '十四', '十五'
]

THIRD_INDEX = list(map(str, range(1, 50)))

FORTH_INDEX = list(string.ascii_lowercase)


OUTLINE_REPLACE_RULES = {
    '週一': ['週　一', '週  一', '週一'],
    '週二': ['週　二', '週  二'],
    '週三': ['週　三', '週  三'],
    '週四': ['週　四', '週  四'],
    '週五': ['週　五', '週  五'],
    '週六': ['週　六', '週  六']
}

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:98.0) Gecko/20100101 Firefox/98.0",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
    "Accept-Encoding": "gzip, deflate",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Sec-Fetch-User": "?1",
    "Cache-Control": "max-age=0",
}


class HtmlParser():

    def __init__(self, html, _type):
        self.page = requests.get(html, headers=HEADERS).text
        self.type = _type
        self.outline_check = OUTLINE_REPLACE_RULES.keys()
        self.day_message_check = ['晨興餧養', 'WEEK', '信息選讀']
        self.training_check = [
            '感恩節國際相調特會', '國際長老及負責弟兄訓練', '冬季', '國際華語特會',
            '春季國際長老及負責弟兄訓練', '國殤節特會', '七月半年度訓練',
            '感恩節特會', '2024年十二月 半年度訓練','2025年六月半年度訓練'
        ]
        self.prefixs = ['<span style="font-size:', '<span style="background-color', '<span style="font-family']

    @staticmethod
    def number_to_chinese(num):
        digits = "零一二三四五六七八九"
        if num == 0:
            return "零"
        if num < 10:
            return digits[num]
        elif num < 20:
            return "十" + (digits[num % 10] if num % 10 != 0 else "")
        else:
            ten = num // 10
            one = num % 10
            return digits[ten] + "十" + (digits[one] if one != 0 else "")

    @staticmethod
    def parse_schedule(code):
        pattern = r"^w(\d{2})-d(\d)-([a-zA-Z]+)$"
        match = re.match(pattern, code)
        if match:
            week_num = int(match.group(1))
            weekday_num = int(match.group(2))
            code_suffix = match.group(3)

            weekday_map = {
                1: "週一", 2: "週二", 3: "週三", 4: "週四",
                5: "週五", 6: "週六", 7: "週日"
            }
            weekday_str = weekday_map.get(weekday_num, f"週{weekday_num}")
            week_str = f"第{HtmlParser.number_to_chinese(week_num)}週"

            return {
                "valid": True,
                "week": week_str,
                "weekday": weekday_str,
                "code": code_suffix
            }
        else:
            return {
                "valid": False,
                "message": "格式不符"
            }

    @staticmethod
    def extract_week_and_title(line):
        if not line:
            return {
                'section_number': '',
                'section_name': ''
            }

        line = re.sub(r'[\xa0\u3000　]+', '', line).strip()
        line = re.sub(r'<[^>]+>', '', line)

        match = re.match(r'^(第[一二三四五六七八九十零百]{1,3}(週|篇))', line)
        if not match:
            return {
                'section_number': '',
                'section_name': line
            }

        section_number = match.group(1)
        remainder = line[len(section_number):].strip()
        section_name = re.sub(r'^[•:：\-\s（）()]*', '', remainder)

        return {
            'section_number': section_number,
            'section_name': section_name
        }

    def _get_text(self, soup):
        if soup.p:
            return soup.p.text
        elif soup.div:
            return soup.div.text
        elif soup.span:
            return soup.span.text
        else:
            raise Exception('Cannot find text')

    def run(self):
        if self.type == 'Training':
            print('In type training')
            return self.parse_training()
        if self.type == 'Outline':
            print('In type outline')
            return self.parse_outline()
        if self.type == 'DayMessage':
            print('In type day_message')
            return self.parse_day_message()

        raise Exception('[ERROR] Cannot find type.')

    def check_training(self):
        for c in self.training_check:
            if c in self.page:
                return True
        return False

    def parse_training(self):
        res = {}
        split_page = self.page.split('\n')
        line = ""
        for c in split_page:
            for tc in self.training_check:
                if tc in c:
                    soup = BeautifulSoup(c, "html.parser")
                    line = soup.h2.text
                    break
            if line:
                break

        line = line.strip()
        if '\xa0' in line:
            line = line.replace('\xa0', '')

        if '─' in line:
            year, tmp_name = line.split('─')
        elif ' ' in line:
            _line_split = line.split(' ')
            if len(_line_split) == 2:
                year = _line_split[0]
                tmp_name = _line_split[1]
            elif len(_line_split) == 3:
                year = _line_split[0]
                tmp_name = _line_split[1] + _line_split[2]
            else:
                raise Exception('[ERROR] Cannot get training year and name.')
        else:
            if '年' in line:
                year_index = line.index('年')
                year = line[:year_index]
                tmp_name = line[year_index + 1:]
            else:
                year = line[:4]
                tmp_name = line[4:]
        training_name, topic = tmp_name.split('『')
        res['training_year'] = year.strip().strip('年')
        res['training_name'] = training_name
        res['training_topic'] = topic.strip('』')
        return res

    def check_prefix(self, line):
        for prefix in self.prefixs:
            if prefix in line:
                return True
        return False

    def parse_day_message(self):
        res = {}
        day_message_data = []
        split_page = self.page.split('\n')
        for c in split_page:
            if self.check_prefix(c):
                if 'WEEK' in c:
                    break
                soup = BeautifulSoup(c, "html.parser")
                line = self._get_text(soup)
                if '\u3000' in line:
                    line = line.replace('\u3000', ' ')
                if '\xa0' in line:
                    line = line.replace('\xa0', '')
                day_message_data.append(line)

        if '•' in day_message_data[0]:
            res['week'], res['day'] = day_message_data[0].split('•')
        elif '■' in day_message_data[0]:
            res['week'], res['day'] = day_message_data[0].split('■')
        elif ' · ' in day_message_data[0]:
            res['week'], res['day'] = day_message_data[0].split(' · ')
        elif '．' in day_message_data[0]:
            res['week'], res['day'] = day_message_data[0].split('．')
        elif ' ' in day_message_data[0]:
            text_split = day_message_data[0].split(' ')
            res['week'] = text_split[0]
            res['day'] = text_split[1]
        elif 'w' in day_message_data[0]:
            get_week_and_day = self.parse_schedule(day_message_data[0])
            print(get_week_and_day)
            res['week'] = get_week_and_day['week']
            res['day'] = get_week_and_day['weekday']
        else:
            print(day_message_data[0])
            raise Exception('[ERROR] Cannot get day message week and day.')
        res['week'] = res['week'].strip()
        res['day'] = res['day'].strip()

        res['data'] = [
            {
                "context": day_message_data,
                "page": "1"
            }
        ]
        return res

    def parse_outline(self):
        res = {}

        outline_data = []
        split_page = self.page.split('\n')
        for c in split_page:
            if self.check_prefix(c):
                if 'Message' in c:
                    break
                if 'Week' in c:
                    break
                soup = BeautifulSoup(c, "html.parser")
                line = self._get_text(soup)
                if '\xa0' in line:
                    line = line.replace('\xa0', '')
                if '\u3000' in line:
                    line = line.replace('\u3000', ' ')
                index = ''
                if ' ' in line:
                    index = line.split()[0]
                if index in SECOND_INDEX:
                    line = '  ' + line
                elif index in THIRD_INDEX:
                    line = '    ' + line
                outline_data.append(line)
        print(outline_data)

        _outline_data = None
        _section_number = None
        _section_name = None
        for _line in outline_data:
            _line = _line.strip()
            if '第' in _line[0]:
                _outline_data = _line
                break
        if not _outline_data:
            raise Exception('[ERROR] Cannot get outline data.')

        result = HtmlParser.extract_week_and_title(_outline_data)
        _section_number = result['section_number']
        _section_name = result['section_name']

        if not _section_number and not _section_name:
            raise Exception('[ERROR] Cannot find section number and name.')

        # 若只有 section_number，有時 section_name 會在下一行
        if not _section_name:
            for _line in outline_data:
                _line = _line.strip()
                if _line == _outline_data:
                    continue
                if _line[0] == 'w':
                    continue
                if '讀經' in _line:
                    raise Exception('[ERROR] Cannot get outline data section name.')
                _section_name = _line
                break

        res['section_number'] = _section_number
        res['section_name'] = _section_name
        print(res)
        res['data'] = [
            {
                "context": outline_data,
                "page": "1"
            }
        ]
        return res

    def _check(self, rules, page):
        for c in rules:
            if c not in page:
                print('[ERROR] %s not in page.' % (c))
                return False
        return True


def next_weekday(d, weekday):
    days_ahead = weekday - d.weekday()
    if days_ahead <= 0:  # Target day already happened this week
        days_ahead += 7
    return d + datetime.timedelta(days_ahead)


def run_once(html, _type):
    hp = HtmlParser(html, _type)
    return hp.run()


def run_section(htmls, fm, current_week=False):
    now = datetime.datetime.now(datetime.timezone.utc)
    if current_week:
        started_day = now - datetime.timedelta(days=now.weekday())
        ended_day = started_day + datetime.timedelta(days=7)
    else:
        started_day = now + datetime.timedelta(days=-now.weekday(), weeks=1)
        ended_day = started_day + datetime.timedelta(days=7)

    res = {}
    res['started_day'] = started_day.replace(minute=0, hour=0, second=0, microsecond=0)
    res['ended_day'] = ended_day.replace(minute=0, hour=0, second=0, microsecond=0)
    res['created_day'] = now
    res['day_messages'] = []
    res['db_version'] = DB_VERSION
    print(res)
    for _type, htmls in htmls.items():
        for html in htmls:
            data = run_once(html, _type)
            print(data)
            data['type'] = _type
            if _type == 'Training':
                res.update(data)
            elif _type == 'Outline':
                res['section_name'] = data['section_name']
                res['section_number'] = data['section_number']
                res['outline'] = data['data']
                print(res)
            elif _type == 'DayMessage':
                res['day_messages'].append(data)
            else:
                print('Invalid')

    if res.get('section_number', '') == '':
        del res['outline'][0]['context'][0]
        res['section_number'] = res['day_messages'][0]['week']
    print(res)
    if DEBUG:
        return
    version = fm.get_metadata_version('stg-metadata', 'metadata')
    upload_version = str(int(version) + 1)
    print('Upload_version: ', upload_version)
    fm.add_section('stg-data', upload_version, res)
    fm.update_metadata_version('stg-metadata', 'metadata', upload_version)

def main():
    from constant import week_htmls
    CURRENT_WEEK = False
    global DEBUG
    DEBUG = True
    fm = FirebaseManager()
    for week_html in week_htmls.values():
        run_section(week_html, fm, current_week=CURRENT_WEEK)

main()
