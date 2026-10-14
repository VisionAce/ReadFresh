#!/usr/bin/env python3
"""從淡水召會取得一週晨興，輸出與 run.py 相同的 Firebase 資料格式。

安裝依賴：python3 -m pip install beautifulsoup4 curl_cffi
執行：python3 run_tamsui.py
預設 DEBUG=True，只輸出資料；設為 False 才寫入原本的 stg collections。
上傳另需 firebase-admin 與 firebase.py 使用的憑證，請從 scripts 目錄執行。
CURRENT_WEEK=False 沿用 run.py 的下週日期（UTC），不是網站刊登日期。
"""

import datetime
import json
import re

from bs4 import BeautifulSoup, NavigableString
from curl_cffi import requests


SOURCE_URL = "https://churchintamsui.wixsite.com/index/morning-revival"
DB_VERSION = "1"
DEBUG = True
CURRENT_WEEK = False

WEEK = r"第[零〇一二三四五六七八九十百兩\d]+週"
TRAINING_TITLE = re.compile(r"^(\d{4})\s*年\s*(.+?)\s*『(.+?)』$")
OUTLINE_TITLE = re.compile(rf"^({WEEK})\s*[：:　 ]\s*(.+)$")
DAY_TITLE = re.compile(rf"^({WEEK})\s*[•．·■]\s*(週[一二三四五六])$")
DAYS = [f"週{day}" for day in "一二三四五六"]


def clean_text(text):
    text = text.replace("\u200b", "").replace("\ufeff", "")
    return re.sub(r"\s+", " ", text).strip()


def content_lines(root):
    """逐段讀取正文，保留 HTML 清單編號及換行，不重複讀取父子元素。"""
    lines = []
    pending = []

    def flush():
        line = clean_text("".join(pending))
        pending.clear()
        if line:
            lines.append(line)

    def walk(node):
        if isinstance(node, NavigableString):
            pending.append(str(node))
            return
        if node.name in {"script", "style"}:
            return
        if node.name == "br":
            flush()
            return
        if node.name in {"ol", "ul"}:
            flush()
            number = int(node.get("start", 1))
            for item in node.find_all("li", recursive=False):
                number = int(item.get("value", number))
                first_line = len(lines)
                walk(item)
                flush()
                if len(lines) > first_line:
                    marker = f"{number}. " if node.name == "ol" else "• "
                    lines[first_line] = marker + lines[first_line]
                number += 1
            return
        block = node.name in {"p", "div", "li", "h1", "h2", "h3", "h4"}
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
        self.soup = BeautifulSoup(html, "html.parser")

    def run(self):
        title = next(
            (tag for tag in self.soup.find_all("h2")
             if TRAINING_TITLE.fullmatch(clean_text(tag.get_text()))),
            None,
        )
        if title is None:
            raise ValueError("找不到特會年份、名稱與主題。")
        # 使用正文 rich-text 元件作邊界，排除導覽列及頁尾聯絡資訊。
        body = title.find_parent(class_="wixui-rich-text")
        if body is None:
            raise ValueError("找不到淡水召會的正文區塊。")
        year, name, topic = TRAINING_TITLE.fullmatch(
            clean_text(title.get_text())
        ).groups()
        lines = content_lines(body)
        outline_start = next(
            (i for i, line in enumerate(lines) if OUTLINE_TITLE.fullmatch(line)),
            None,
        )
        if outline_start is None:
            raise ValueError("找不到週次與綱目標題。")
        week, section_name = OUTLINE_TITLE.fullmatch(lines[outline_start]).groups()
        headings = [
            (i, match) for i, line in enumerate(lines)
            if (match := DAY_TITLE.fullmatch(line))
        ]
        if [match.group(2) for _, match in headings] != DAYS:
            raise ValueError("每日信息必須依序包含週一至週六，且不得重複。")
        if any(match.group(1) != week for _, match in headings):
            raise ValueError("每日信息週次與綱目不一致。")
        if headings[0][0] <= outline_start:
            raise ValueError("綱目與每日信息的順序不正確。")

        outline = lines[outline_start:headings[0][0]]
        if not any(line.startswith("讀經") for line in outline):
            raise ValueError("綱目缺少讀經內容。")
        if not any(re.match(r"[壹貳贰參叁肆伍陸陆柒捌玖拾]、", line)
                   for line in outline):
            raise ValueError("綱目缺少主要段落。")
        outline = [
            re.sub(r"[【〖]\s*週\s*([一二三四五六])\s*[】〗]", r"週\1", line)
            for line in outline
        ]
        messages = []
        for day_index, (start, match) in enumerate(headings):
            end = headings[day_index + 1][0] if day_index < 5 else len(lines)
            context = lines[start:end]
            for marker in ("晨興餧養", "信息選讀"):
                if context.count(marker) != 1:
                    raise ValueError(f"{match.group(2)} 缺少或重複「{marker}」。")
            feeding = context.index("晨興餧養")
            reading = context.index("信息選讀")
            if not (feeding + 1 < reading < len(context) - 1):
                raise ValueError(f"{match.group(2)} 的晨興餧養或信息選讀內容不完整。")
            messages.append({
                "week": week,
                "day": match.group(2),
                "type": "DayMessage",
                "data": [{"context": context, "page": "1"}],
            })
        return {
            "training_year": year,
            "training_name": name.strip(),
            "training_topic": topic.strip(),
            "type": "Training",
            "section_number": week,
            "section_name": section_name,
            "outline": [{"context": outline, "page": "1"}],
            "day_messages": messages,
        }


def run_section(url=SOURCE_URL, fm=None, current_week=False):
    response = requests.get(url, impersonate="chrome", timeout=60)
    response.raise_for_status()
    res = TamsuiParser(response.text).run()
    now = datetime.datetime.now(datetime.timezone.utc)
    started_day = (now - datetime.timedelta(days=now.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    if not current_week:
        started_day += datetime.timedelta(days=7)
    res.update({
        "started_day": started_day,
        "ended_day": started_day + datetime.timedelta(days=7),
        "created_day": now,
        "db_version": DB_VERSION,
    })
    print(json.dumps(res, ensure_ascii=False, indent=2, default=str))
    if DEBUG:
        return res

    # DEBUG 模式不需要 Firebase 憑證，也不初始化 Firebase client。
    if fm is None:
        from firebase import FirebaseManager
        fm = FirebaseManager()
    version = fm.get_metadata_version("stg-metadata", "metadata")
    upload_version = str(int(version) + 1)
    print("Upload_version:", upload_version)
    fm.add_section("stg-data", upload_version, res)
    fm.update_metadata_version("stg-metadata", "metadata", upload_version)
    return res


def main():
    run_section(current_week=CURRENT_WEEK)


if __name__ == "__main__":
    main()
