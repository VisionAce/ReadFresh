#!/usr/local/bin/python3

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
        self.outline_check = ['週一','週二','週三','週四','週五','週六']
        self.day_message_check = ['晨興餧養', 'WEEK', '信息選讀']
        self.training_check = ['感恩節國際相調特會','秋季國際長老及負責弟兄訓練']
        self.prefix = '<span style="font-size:'

    def _get_text(self, soup):
        if soup.p:
            return soup.p.text
        elif soup.div:
            return soup.div.text
        else:
            raise Exception('Cannot find text')

    def run(self):
        if self.check_training():
            print('Training')
            return self.parse_training()
        elif self._check(self.outline_check, self.page):
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
        year, tmp_name = line.split('─')
        training_name, topic = tmp_name.split('『') 
        res['training_year'] = year.strip()
        res['training_name'] = training_name
        res['training_topic'] = topic.strip('』')
        res['type'] = 'Training'
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
                day_message_data.append(line)
        res['week'] = day_message_data[0][:3]
        res['day'] = day_message_data[0][4:]
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
        print(outline_data)
        res['section_number'] = outline_data[0]
        res['section_name'] = outline_data[1]
        res['data'] = [
            {
                "context" : outline_data,
                "page": "1"
            }
        ]
        res['type'] = 'Outline'
        #print(res)
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
    now = datetime.datetime.utcnow()
    if current_week:
        started_day = now - datetime.timedelta(days=now.weekday())
        ended_day = started_day + datetime.timedelta(days=6)
    else:
        started_day = now + datetime.timedelta(days=-now.weekday(), weeks=1)
        ended_day =  started_day + datetime.timedelta(days=6)
    print(now)
    print(started_day)
    print(ended_day)
    res = {}
    res['started_day'] = started_day
    res['ended_day'] = ended_day
    res['created_day'] = now
    res['day_messages'] = []
    res['db_version'] = DB_VERSION
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
        elif _type == 'DayMessage':
            res['day_messages'].append(data)
        else:
            print('Invalid')
    #print(res)
    if DEBUG:
        return
    version = fm.get_metadata_version('stg-metadata', 'metadata')
    upload_version = str(int(version) + 1)
    print('Upload_version: ', upload_version)
    fm.add_section('stg-data', upload_version, res)
    fm.update_metadata_version('stg-metadata', 'metadata', upload_version)

def main():
    from constant import week_htmls
    CURRENT_WEEK = True
    global DEBUG
    DEBUG = False
    fm = FirebaseManager()
    for week_html in week_htmls.values():
        run_section(week_html, fm, current_week=CURRENT_WEEK)

main()
