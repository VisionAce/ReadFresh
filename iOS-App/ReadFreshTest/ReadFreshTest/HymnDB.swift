//
//  HymnDB.swift
//  ReadFreshTest
//

import Foundation
import SQLite3

class HymnDB {
    static let shared = HymnDB()
    private var db: OpaquePointer?

    private init() {
        guard let path = Bundle.main.path(forResource: "hymns", ofType: "db") else {
            print("[HymnDB] hymns.db not found in bundle")
            return
        }
        if sqlite3_open(path, &db) != SQLITE_OK {
            print("[HymnDB] Failed to open database")
        }
    }

    deinit { sqlite3_close(db) }

    struct HymnRow {
        let article: Int
        let serial: Int
        let lyric: String
    }

    struct ChorusRow {
        let begin: Int
        let end: Int
        let chorus: String
    }

    func getHymn(catalog: Int, number: String) -> [HymnRow] {
        var rows = [HymnRow]()
        let sql = "SELECT article, serial, lyric FROM hymnal WHERE language='big5' AND catalog=? AND number=? ORDER BY article, serial"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(catalog))
        sqlite3_bind_text(stmt, 2, (number as NSString).utf8String, -1, nil)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let article = Int(sqlite3_column_int(stmt, 0))
            let serial = Int(sqlite3_column_int(stmt, 1))
            let lyric = String(cString: sqlite3_column_text(stmt, 2))
            rows.append(HymnRow(article: article, serial: serial, lyric: lyric))
        }
        return rows
    }

    func getChorus(catalog: Int, number: String) -> [ChorusRow] {
        var rows = [ChorusRow]()
        let sql = "SELECT begin, end, chorus FROM hchorus WHERE language='big5' AND catalog=? AND number=? ORDER BY serial"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(catalog))
        sqlite3_bind_text(stmt, 2, (number as NSString).utf8String, -1, nil)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let begin = Int(sqlite3_column_int(stmt, 0))
            let end = Int(sqlite3_column_int(stmt, 1))
            let chorus = String(cString: sqlite3_column_text(stmt, 3))
            rows.append(ChorusRow(begin: begin, end: end, chorus: chorus))
        }
        return rows
    }

    func hymnExists(catalog: Int, number: String) -> Bool {
        let sql = "SELECT COUNT(*) FROM hymnal WHERE language='big5' AND catalog=? AND number=?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(catalog))
        sqlite3_bind_text(stmt, 2, (number as NSString).utf8String, -1, nil)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int(stmt, 0) > 0
        }
        return false
    }
}
