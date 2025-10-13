#!/usr/bin/python3
# -*- coding: utf-8 -*-

import firebase_admin
from firebase_admin import credentials, firestore


class FirebaseManager:
    def __init__(self):
        cred = credentials.Certificate('readfresh-3c7d8-firebase-adminsdk-gf1jy-b1d4cff46d.json')
        # 避免重複初始化 Firebase
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        self.db = firestore.client()

    def _set(self, collection, document, data):
        doc_ref = self.db.collection(collection).document(document)
        doc_ref.set(data)

    def _get(self, collection, document):
        metadata_ref = self.db.collection(collection).document(document)
        return metadata_ref.get().to_dict()

    def update_metadata_version(self, collection, document, version):
        data = {'version': version}
        self._set(collection, document, data)

    def get_metadata_version(self, collection, document):
        return self._get(collection, document)['version']

    def add_section(self, collection, document, data):
        self._set(collection, document, data)

    # === 新增功能 ===
    def get_all_documents(self, collection):
        """取得指定 collection 下的所有文件"""
        docs = self.db.collection(collection).stream()
        result = {}
        for doc in docs:
            result[doc.id] = doc.to_dict()
        return result

    def delete_document(self, collection, doc_id):
        """刪除指定文件"""
        self.db.collection(collection).document(doc_id).delete()

#FM = FirebaseManager()
#version = FM.get_metadata_version('stg-metadata', 'metadata')
#FM.update_metadata_version('stg-metadata', 'metadata', version+1)
