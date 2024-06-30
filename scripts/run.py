#!/usr/bin/python3

import pandas as pd
import string
import requests
import datetime
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


class HtmlParser():

    def __init__(self, html):
        self.page = requests.get(html).text
        self.outline_check1 = ['週一','週二','週三','週四','週五','週六']
        self.outline_check2 = ['週　一','週　二','週　三','週　四','週　五','週　六']
        self.outline_check3 = ['週　一','週二','週三','週　四','週　五','週　六']
        self.day_message_check = ['晨興餧養', 'WEEK', '信息選讀']
        self.training_check = ['感恩節國際相調特會', '秋季國際長老及負責弟兄訓練', '冬季', '國際華語特會', '春季國際長老及負責弟兄訓練', '國殤節特會']
        self.prefix = '<span style="font-size:'

    def _get_text(self, soup):
        if soup.p:
            return soup.p.text
        elif soup.div:
            return soup.div.text
        elif soup.span:
            return soup.span.text
        else:
            #print(soup)
            raise Exception('Cannot find text')

    def run(self):
        if self._check(self.outline_check2, self.page):
            for i in range(len(self.outline_check2)):
                self.page = self.page.replace(self.outline_check2[i], self.outline_check1[i])
        if self._check(self.outline_check3, self.page):
            for i in range(len(self.outline_check3)):
                self.page = self.page.replace(self.outline_check3[i], self.outline_check1[i])
        if self.check_training():
            print('Training')
            return self.parse_training()
        elif self._check(self.outline_check1, self.page):
            print('Outline')
            #print(self.page)
            return self.parse_outline()
        elif self._check(self.day_message_check, self.page):
            #print(self.page)
            print('Day message')
            return self.parse_day_message()
        else:
            print('Skip Html')

    def check_training(self):
        #print(self.page)
        for c in self.training_check:
            if c in self.page:
                return True
        return False

    def parse_training(self):
        res = {}
        split_page = self.page.split('\n')
        for c in split_page:
            for tc in self.training_check:
                if tc in c:
                    soup = BeautifulSoup(c, "html.parser")
                    line = soup.h2.text
                    break
        #print(line)
        if '─' in line:
            year, tmp_name = line.split('─')
        elif ' ' in line:
            year, tmp_name = line.split(' ')
        # Fix 2024國際華語特會『打美好的仗，跑盡賽程，守住信仰，並愛主的顯現，好得著基督作公義冠冕的獎賞 』
        else:
            year = line[:4]
            tmp_name = line[4:]
        training_name, topic = tmp_name.split('『')
        res['training_year'] = year.strip()
        res['training_name'] = training_name
        res['training_topic'] = topic.strip('』')
        res['type'] = 'Training'
        #print(res)
        return res

    def parse_day_message(self):
        res = {}
        day_message_data = []
        split_page = self.page.split('\n')
        for c in split_page:
            if self.prefix in c:
                if 'WEEK' in c:
                    break
                soup = BeautifulSoup(c, "html.parser")
                line = self._get_text(soup)
                if '\u3000' in line:
                    line = line.replace('\u3000', ' ')
                if '\xa0' in line:
                    line = line.replace('\xa0', '')
                day_message_data.append(line)
        
        # Fix 第十一週•週四
        if '•' in day_message_data[0]:
            res['week'], res['day'] = day_message_data[0].split('•')
        # Fix 2024 春季國際長老及負責弟兄訓練 第一週■週一
        elif '■' in day_message_data[0]:
            res['week'], res['day'] = day_message_data[0].split('■')
        res['week'] = res['week'].strip()
        res['day'] = res['day'].strip()
        #res['week'] = day_message_data[0][:3]
        #res['day'] = day_message_data[0][-2:]

        # Support page
        res['data'] = [
            {
                "context" : day_message_data,
                "page": "1"
            }
        ]
        res['type'] = 'DayMessage'
        return res


    def parse_outline(self):
        res = {}
      
        outline_data = []
        split_page = self.page.split('\n')
        for c in split_page:
            if self.prefix in c:
                #print(c)
                if 'Message' in c:
                    break
                if 'Week' in c:
                    break
                soup = BeautifulSoup(c, "html.parser")
                line = self._get_text(soup)
                if '\u3000' in line:
                    line = line.replace('\u3000', ' ')
                index = ''
                if ' ' in line:
                    index = line.split()[0]
                #if index in TOP_INDEX:
                if index in SECOND_INDEX:
                    line =  '  ' + line
                elif index in THIRD_INDEX:
                    line = '    ' + line
                else:
                    pass
                    #print('Else: ', line)
                outline_data.append(line)
        #print(outline_data)
        #print(outline_data)
        # Fix 2023年 冬季訓練『經營美地所豫表包羅萬有的基督，為着建造召會作基督的身體，為着國度的實際與實現，並為着新婦得以為主的來臨將自己豫備好』
        # Fix 2024年 國殤節特會 接枝的生命 "第二週 • 綱目"
        if '•' in outline_data[0]:
            not_space = outline_data[0].strip()
            parts = not_space.split('•')
            _section_number = parts[0].strip()
            _section_name = outline_data[1]
        elif ' ' in outline_data[0]:
            _section_number, _section_name = outline_data[0].split()
        else:
            if outline_data[0][0] != '第' and outline_data[0][-1] != '週':
                outline_data = [''] + outline_data
            _section_number = outline_data[0]
            _section_name = outline_data[1]
        res['section_number'] = _section_number
        res['section_name'] = _section_name
        print(res)
        res['data'] = [
            {
                "context" : outline_data,
                "page": "1"
            }
        ]
        res['type'] = 'Outline'
        return res

    def _check(self, rules, page):
        for c in rules:
            if c not in page:
                return False
        return True

 
def next_weekday(d, weekday):
    days_ahead = weekday - d.weekday()
    if days_ahead <= 0: # Target day already happened this week
        days_ahead += 7
    return d + datetime.timedelta(days_ahead)

def run_once(html):
    hp = HtmlParser(html)
    return hp.run()

def run_section(htmls, fm, current_week=False):
    #html='https://classic-blog.udn.com/ymch130/180049577'
    now = datetime.datetime.now(datetime.timezone.utc)
    if current_week:
        started_day = now - datetime.timedelta(days=now.weekday())
        ended_day = started_day + datetime.timedelta(days=7)
    else:
        started_day = now + datetime.timedelta(days=-now.weekday(), weeks=1)
        ended_day =  started_day + datetime.timedelta(days=7)
    #print(now)
    #print(started_day)
    #print(ended_day)
    res = {}
    res['started_day'] = started_day.replace(minute=0, hour=0, second=0, microsecond=0)
    res['ended_day'] = ended_day.replace(minute=0, hour=0, second=0, microsecond=0)
    res['created_day'] = now
    res['day_messages'] = []
    res['db_version'] = DB_VERSION
    print(res)
    for html in htmls:
        data = run_once(html)
        print(data)
        _type = data['type']
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
        
    if res['section_number'] == '':
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
