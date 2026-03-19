#!/usr/bin/python3

import pandas as pd
import string
import datetime
import random
import re
from bs4 import BeautifulSoup
# 使用 curl_cffi 替換標準 requests 以突破 Akamai 403 防火牆
from curl_cffi import requests
from firebase import FirebaseManager

# Update DB version if database structure changed
DB_VERSION = "1"

TOP_INDEX = ['壹', '贰', '叁', '肆', '伍',  '陆',  '柒', '捌', '玖', '拾']

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

class HtmlParser():

    def __init__(self, html, _type):
        # impersonate="chrome" 會完美偽裝底層 TLS 指紋，讓防火牆以為這是真實的 Chrome 瀏覽器
        response = requests.get(html, impersonate="chrome")
        self.page = response.text
        
        if response.status_code != 200:
            print(f"[ERROR] 網址: {html}")
            raise Exception(f"請求失敗，狀態碼: {response.status_code} (若仍為403，表示目前 IP 已被暫時封鎖，請切換手機網路再試)")
            
        self.type = _type
        self.outline_check = OUTLINE_REPLACE_RULES.keys()
        self.day_message_check = ['晨興餧養', 'WEEK', '信息選讀']
        self.training_check = ['感恩節國際相調特會', '國際長老及負責弟兄訓練', '冬季', '國際華語特會', '春季國際長老及負責弟兄訓練', '國殤節特會', '七月半年度訓練','感恩節特會','2024年十二月 半年度訓練','2025年十二月半年度訓練','十二月半年度訓練']
        self.prefixs = [
            'font-size:',
            'font-family:',
            'background-color:',
            'MsoNormal'
        ]
    
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
            week_num = int(match.group(1))  # 數字週
            weekday_num = int(match.group(2))  # 數字星期
            code_suffix = match.group(3)

            weekday_map = {
               1: "週一", 2: "週二", 3: "週三", 4: "週四", 5: "週五", 6: "週六", 7: "週日"
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
        soup = BeautifulSoup(self.page, "html.parser")
        line = ""
        
        # 尋找包含特會名稱的 h2 標籤
        for h2 in soup.find_all('h2'):
            text = h2.get_text(strip=True)
            if any(tc in text for tc in self.training_check):
                line = text
                break
                
        # Fallback: 如果不在 h2 裡，找其他的段落
        if not line:
            for tag in soup.find_all(['p', 'div', 'span', 'h3']):
                text = tag.get_text(strip=True)
                if any(tc in text for tc in self.training_check):
                    line = text
                    break

        line = line.strip()
        if '\xa0' in line:
            line = line.replace('\xa0', '')

        if not line:
            raise Exception('[ERROR] Cannot get training data line.')

        if '─' in line:
            year, tmp_name = line.split('─')
        elif ' ' in line:
            _line_split = line.split(' ')
            if len(_line_split) >= 2:
                year = _line_split[0]
                tmp_name = "".join(_line_split[1:])
            else:
                raise Exception('[ERROR] Cannot get training year and name.')
        else:
            if '年' in line:
                year_index = line.index('年')
                year = line[:year_index]
                tmp_name = line[year_index+1:]
            else:
                year = line[:4]
                tmp_name = line[4:]
                
        training_name, topic = tmp_name.split('『')
        res['training_year'] = year.strip().strip('年')
        res['training_name'] = training_name.strip()
        res['training_topic'] = topic.strip('』').strip()
        return res

    def parse_day_message(self):
        res = {}
        day_message_data = []
        soup = BeautifulSoup(self.page, "html.parser")
        
        # 定位主內容區塊，避免抓到網頁旁支的雜訊
        main_body = soup.find(id="mainbody")
        if not main_body:
            main_body = soup # Fallback 找全部
            
        for tag in main_body.find_all(['p', 'div']):
            line = tag.get_text()
            if '\u3000' in line:
                line = line.replace('\u3000', ' ')
            if '\xa0' in line:
                line = line.replace('\xa0', '')
            
            line = line.strip()
            
            if not line:
                continue
                
            # 遇到英文版時中止
            if 'WEEK' in line.upper():
                break
                
            day_message_data.append(line)

        if not day_message_data:
            raise Exception('[ERROR] Cannot get day message data.')

        first_line = day_message_data[0]

        # 分割星期與日期
        if '•' in first_line:
            res['week'], res['day'] = first_line.split('•')
        elif '■' in first_line:
            res['week'], res['day'] = first_line.split('■')
        elif ' · ' in first_line:
            res['week'], res['day'] = first_line.split(' · ')
        elif '．' in first_line:
            res['week'], res['day'] = first_line.split('．')
        elif ' ' in first_line and 'w' not in first_line:
            text_split = first_line.split(' ')
            if len(text_split) >= 2:
                res['week'] = text_split[0]
                res['day'] = text_split[1]
        elif 'w' in first_line:
            get_week_and_day = self.parse_schedule(first_line)
            res['week'] = get_week_and_day['week']
            res['day'] = get_week_and_day['weekday']
        else:
            print(f"First line content: {first_line}")
            raise Exception('[ERROR] Cannot get day message week and day.')
            
        res['week'] = res['week'].strip()
        res['day'] = res['day'].strip()

        res['data'] = [
            {
                "context" : day_message_data,
                "page": "1"
            }
        ]
        return res

    def parse_outline(self):
        res = {}
        outline_data = []
        soup = BeautifulSoup(self.page, "html.parser")

        # 定位主內容區塊
        main_body = soup.find(id="mainbody")
        if not main_body:
            main_body = soup # Fallback 找全部

        for p in main_body.find_all(['p', 'div']):
            line = p.get_text()
            
            if '\xa0' in line:
                line = line.replace('\xa0', '')
            if '\u3000' in line:
                line = line.replace('\u3000', ' ')
            line = line.strip()

            if not line:
                continue

            if 'Message' in line or 'Week' in line:
                break

            index = ''
            if ' ' in line:
                index = line.split(' ')[0]

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
            if _line and _line.startswith('第'):
                _outline_data = _line
                break
                
        if not _outline_data:
            raise Exception('[ERROR] Cannot get outline data. Is the page empty or formatting extremely different?')

        # 拆分大綱標題
        if '•' in _outline_data:
            if '綱目' in _outline_data:
                _section_number = _outline_data.split('•')[0].strip()
                _section_name = outline_data[1].strip()
            else:
                _section_number, _section_name = _outline_data.split('•', 1)
        elif '　' in _outline_data:
            _outline_data_split = _outline_data.split('　', 1)
            if len(_outline_data_split) == 2:
                _section_number = _outline_data_split[0]
                _section_name = _outline_data_split[1]
        elif ' ' in _outline_data:
            _outline_data_split = _outline_data.split(' ', 1)
            if len(_outline_data_split) == 2:
                _section_number = _outline_data_split[0]
                _section_name = _outline_data_split[1]
        elif _outline_data[-1] in ['篇', '週'] and len(_outline_data) == 3:
            _section_number = _outline_data
        else:
            raise Exception(f'[ERROR] Cannot find section number and name in: {_outline_data}')
            
        # 修正標題不在第一行的情況
        if not _section_name:
            for _line in outline_data:
                _line = _line.strip()
                if _line == _outline_data or _line.startswith('w'):
                    continue
                if '讀經' in _line:
                    raise Exception('[ERROR] Cannot get outline data section name.')
                _section_name = _line
                break

        res['section_number'] = _section_number.strip() if _section_number else ""
        res['section_name'] = _section_name.strip() if _section_name else ""
        
        res['data'] = [
            {
                "context" : outline_data,
                "page": "1"
            }
        ]
        return res

def next_weekday(d, weekday):
    days_ahead = weekday - d.weekday()
    if days_ahead <= 0: # Target day already happened this week
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
        ended_day =  started_day + datetime.timedelta(days=7)
        
    res = {}
    res['started_day'] = started_day.replace(minute=0, hour=0, second=0, microsecond=0)
    res['ended_day'] = ended_day.replace(minute=0, hour=0, second=0, microsecond=0)
    res['created_day'] = now
    res['day_messages'] = []
    res['db_version'] = DB_VERSION
    print(res)
    
    for _type, htmls_list in htmls.items():
        for html in htmls_list:
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
                print('Invalid Type')
                
    if res.get('section_number', '') == '' and res.get('outline') and res.get('day_messages'):
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

if __name__ == "__main__":
    main()

