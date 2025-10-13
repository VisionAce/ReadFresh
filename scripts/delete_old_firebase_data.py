#!/usr/bin/python3
# -*- coding: utf-8 -*-

import datetime
from firebase import FirebaseManager

# === 設定 ===
TARGET_COLLECTION = "stg-data"  # 要清理的 collection 名稱
DELETE_THRESHOLD_YEARS = 1      # 超過幾年要刪除
DELETE_THRESHOLD_MONTHS = 8     # 超過幾個月要刪除
DEBUG_MODE = True               # ⚠️ True = 模擬模式（dry-run，不會真的刪除）


def delete_old_data():
    """
    刪除 Firebase 中 created_day 超過指定年限（年 + 月）的資料
    """
    fm = FirebaseManager()

    now = datetime.datetime.now(datetime.timezone.utc)

    # 以平均每月 30.44 天計算
    months_to_days = (DELETE_THRESHOLD_YEARS * 12 + DELETE_THRESHOLD_MONTHS) * 30.44
    threshold_date = now - datetime.timedelta(days=months_to_days)

    print(f"[INFO] Threshold date for deletion: {threshold_date.isoformat()}")
    print(f"[INFO] DEBUG_MODE = {DEBUG_MODE}")

    # 取得所有文件
    all_docs = fm.get_all_documents(TARGET_COLLECTION)
    print(f"[INFO] Total documents fetched: {len(all_docs)}")

    delete_count = 0
    simulated_count = 0

    for doc_id, doc_data in all_docs.items():
        created_day = doc_data.get("created_day")

        if not created_day:
            print(f"[WARN] Document '{doc_id}' has no 'created_day' field, skipping.")
            continue

        # 若 Firebase 儲存為 timestamp 或字串，進行轉換
        if isinstance(created_day, str):
            try:
                created_day = datetime.datetime.fromisoformat(created_day)
            except Exception:
                print(f"[WARN] Invalid 'created_day' format in {doc_id}: {created_day}")
                continue
        elif isinstance(created_day, datetime.datetime):
            pass
        else:
            print(f"[WARN] Unknown type for 'created_day' in {doc_id}: {type(created_day)}")
            continue

        # 判斷是否超過門檻日期
        if created_day < threshold_date:
            if DEBUG_MODE:
                print(f"[SIMULATE DELETE] {doc_id} created on {created_day} (older than threshold)")
                simulated_count += 1
            else:
                print(f"[DELETE] {doc_id} created on {created_day}, deleting...")
                fm.delete_document(TARGET_COLLECTION, doc_id)
                delete_count += 1

    # 結果摘要
    if DEBUG_MODE:
        print(f"[INFO] Simulation complete. {simulated_count} documents would be deleted.")
    else:
        print(f"[INFO] Deletion complete. {delete_count} documents deleted.")


def main():
    print("[START] Firebase old data cleanup started.")
    delete_old_data()
    print("[DONE] Firebase cleanup finished.")


if __name__ == "__main__":
    main()
