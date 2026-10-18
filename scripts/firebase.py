#!/usr/bin/env python3
"""Firestore access for ReadFresh; credentials must not be committed to Git."""
import json
import os

import firebase_admin
from firebase_admin import credentials, firestore


class FirebaseManager:
    def __init__(self):
        if not firebase_admin._apps:
            raw = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')
            path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
            if raw:
                try:
                    info = json.loads(raw)
                except json.JSONDecodeError as exc:
                    raise ValueError('FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON') from exc
                cred = credentials.Certificate(info)
            elif path:
                cred = credentials.Certificate(path)
            else:
                raise RuntimeError('Set FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS')
            firebase_admin.initialize_app(cred)
        self.db = firestore.client()

    def _set(self, collection, document, data):
        self.db.collection(collection).document(str(document)).set(data)

    def _get(self, collection, document):
        snapshot = self.db.collection(collection).document(str(document)).get()
        if not snapshot.exists:
            raise ValueError(f'Missing Firestore document: {collection}/{document}')
        return snapshot.to_dict() or {}

    def update_metadata_version(self, collection, document, version):
        # Preserve any future metadata fields.
        self.db.collection(collection).document(str(document)).update({'version': str(version)})

    def get_metadata_version(self, collection, document):
        data = self._get(collection, document)
        if 'version' not in data:
            raise ValueError(f'Missing version in {collection}/{document}')
        return data['version']

    def add_section(self, collection, document, data):
        # Refuse accidental overwrite of existing weeks.
        self.db.collection(collection).document(str(document)).create(data)

    def get_all_documents(self, collection):
        return {doc.id: doc.to_dict() or {} for doc in self.db.collection(collection).stream()}

    def delete_document(self, collection, doc_id):
        self.db.collection(collection).document(str(doc_id)).delete()

    def sync_tamsui(self, incoming, identity, comparable):
        """Compare existing weeks; atomically create next numbered document and bump version.

        Use GitHub Actions concurrency to serialize runs. For independent writers,
        coordinate through a shared lock or an additional deterministic document.
        """
        matches = [(doc_id, data) for doc_id, data in self.get_all_documents('stg-data').items()
                   if identity(data) == identity(incoming)]
        if matches:
            if all(comparable(data) == comparable(incoming) for _, data in matches):
                return 'skipped', matches[0][0]
            raise ValueError('Same training/week exists with different content; manual review required')

        meta_ref = self.db.collection('stg-metadata').document('metadata')
        transaction = self.db.transaction()

        @firestore.transactional
        def commit(tx):
            meta = meta_ref.get(transaction=tx)
            if not meta.exists:
                raise ValueError('Missing stg-metadata/metadata')
            raw_version = (meta.to_dict() or {}).get('version')
            if isinstance(raw_version, bool) or not str(raw_version).isdigit():
                raise ValueError(f'Invalid metadata version: {raw_version!r}')
            next_version = str(int(raw_version) + 1)
            next_ref = self.db.collection('stg-data').document(next_version)
            if next_ref.get(transaction=tx).exists:
                raise ValueError(f'stg-data/{next_version} already exists; refusing overwrite')
            tx.create(next_ref, incoming)
            tx.update(meta_ref, {'version': next_version})
            return next_version

        version = commit(transaction)
        return 'created', version
