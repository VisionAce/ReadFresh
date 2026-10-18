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

    @staticmethod
    def _version_number(raw_version):
        if isinstance(raw_version, bool) or not str(raw_version).isdigit():
            raise ValueError(f'Invalid metadata version: {raw_version!r}')
        return int(raw_version)

    def get_latest_section(self):
        """Return (metadata.version as document ID, latest stg-data document)."""
        raw_version = self.get_metadata_version('stg-metadata', 'metadata')
        version = str(self._version_number(raw_version))
        return version, self._get('stg-data', version)

    def sync_tamsui(self, incoming, comparable):
        """Atomically compare latest version and append only if content changed.

        All Firestore reads happen before writes inside the transaction. A
        concurrent writer changing metadata triggers a transaction retry.
        Existing stg-data documents are never overwritten or deleted.
        """
        meta_ref = self.db.collection('stg-metadata').document('metadata')
        data_collection = self.db.collection('stg-data')

        @firestore.transactional
        def commit(tx):
            meta_snap = meta_ref.get(transaction=tx)
            if not meta_snap.exists:
                raise ValueError('Missing stg-metadata/metadata')
            metadata = meta_snap.to_dict() or {}
            raw_version = metadata.get('version')
            current_version = self._version_number(raw_version)
            current_ref = data_collection.document(str(current_version))
            current_snap = current_ref.get(transaction=tx)
            if not current_snap.exists:
                raise ValueError(f'Missing stg-data/{current_version}')

            if comparable(current_snap.to_dict() or {}) == comparable(incoming):
                return 'skipped', str(current_version)

            next_version = current_version + 1
            next_ref = data_collection.document(str(next_version))
            # Must read before any writes within Firestore transactions.
            if next_ref.get(transaction=tx).exists:
                raise ValueError(f'stg-data/{next_version} already exists; refusing overwrite')

            tx.create(next_ref, incoming)
            # Keep the existing version field's type (string or integer).
            new_value = str(next_version) if isinstance(raw_version, str) else next_version
            tx.update(meta_ref, {'version': new_value})
            return 'created', str(next_version)

        return commit(self.db.transaction())
