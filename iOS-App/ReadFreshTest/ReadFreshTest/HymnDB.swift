//
//  HymnDB.swift
//  ReadFreshTest
//

import Foundation
import SQLite3

class HymnDB {
    static let shared = HymnDB()
    private var db: OpaquePointer?
    private let language = "big5"
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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

    struct HymnRow: Hashable {
        let article: Int
        let serial: Int
        let lyric: String
    }

    struct ChorusRow: Hashable {
        let article: Int
        let begin: Int
        let end: Int
        let chorus: String
    }

    struct HymnSummary: Hashable, Identifiable, Codable {
        let catalog: Int
        let number: String
        let title: String

        var id: String { "\(catalog)-\(number)" }
    }

    struct HymnSearchResult: Hashable, Identifiable {
        let summary: HymnSummary
        let excerpt: String

        var id: String { summary.id }
    }

    struct DirectoryEntry: Hashable, Identifiable {
        let catalog: Int
        let level: Int
        let title: String
        let begin: Int
        let end: Int
        let groupID: Int

        var id: String { "\(catalog)-\(level)-\(groupID)-\(begin)-\(end)-\(title)" }
    }

    func getHymn(catalog: Int, number: String) -> [HymnRow] {
        var rows = [HymnRow]()
        let sql = "SELECT article, serial, lyric FROM hymnal WHERE language='big5' AND catalog=? AND number=? ORDER BY article, CAST(serial AS INTEGER)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(catalog))
        sqlite3_bind_text(stmt, 2, number, -1, transient)
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
        let sql = "SELECT article, begin, end, chorus FROM hchorus WHERE language='big5' AND catalog=? AND number=? ORDER BY article, serial"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(catalog))
        sqlite3_bind_text(stmt, 2, number, -1, transient)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let article = Int(sqlite3_column_int(stmt, 0))
            let begin = Int(sqlite3_column_int(stmt, 1))
            let end = Int(sqlite3_column_int(stmt, 2))
            let chorus = String(cString: sqlite3_column_text(stmt, 3))
            rows.append(ChorusRow(article: article, begin: begin, end: end, chorus: chorus))
        }
        return rows
    }

    func hymnExists(catalog: Int, number: String) -> Bool {
        let sql = "SELECT COUNT(*) FROM hymnal WHERE language='big5' AND catalog=? AND number=?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(catalog))
        sqlite3_bind_text(stmt, 2, number, -1, transient)
        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int(stmt, 0) > 0
        }
        return false
    }

    func getTitle(catalog: Int, number: String) -> String {
        let sql = "SELECT lyric FROM hymnal WHERE language=? AND catalog=? AND number=? AND CAST(serial AS INTEGER)=0 ORDER BY article LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return "" }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, language, -1, transient)
        sqlite3_bind_int(stmt, 2, Int32(catalog))
        sqlite3_bind_text(stmt, 3, number, -1, transient)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return "" }
        return cleanTitle(textColumn(stmt, 0))
    }

    func getDirectory(catalog: Int, level: Int, groupID: Int? = nil) -> [DirectoryEntry] {
        var rows = [DirectoryEntry]()
        let sql: String
        if groupID == nil {
            sql = "SELECT level, dir, begin, end, group_id FROM hdir WHERE language=? AND catalog=? AND level=? ORDER BY group_id, begin, end"
        } else {
            sql = "SELECT level, dir, begin, end, group_id FROM hdir WHERE language=? AND catalog=? AND level=? AND group_id=? ORDER BY begin, end"
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, language, -1, transient)
        sqlite3_bind_int(stmt, 2, Int32(catalog))
        sqlite3_bind_int(stmt, 3, Int32(level))
        if let groupID {
            sqlite3_bind_int(stmt, 4, Int32(groupID))
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(DirectoryEntry(
                catalog: catalog,
                level: Int(sqlite3_column_int(stmt, 0)),
                title: textColumn(stmt, 1),
                begin: Int(sqlite3_column_int(stmt, 2)),
                end: Int(sqlite3_column_int(stmt, 3)),
                groupID: Int(sqlite3_column_int(stmt, 4))
            ))
        }
        return rows
    }

    func getHymns(catalog: Int, begin: Int, end: Int) -> [HymnSummary] {
        var rows = [HymnSummary]()
        let sql = """
        SELECT number, lyric
        FROM hymnal
        WHERE language=? AND catalog=? AND CAST(serial AS INTEGER)=0
          AND number NOT LIKE '附%' AND CAST(number AS INTEGER) BETWEEN ? AND ?
        ORDER BY CAST(number AS INTEGER)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, language, -1, transient)
        sqlite3_bind_int(stmt, 2, Int32(catalog))
        sqlite3_bind_int(stmt, 3, Int32(begin))
        sqlite3_bind_int(stmt, 4, Int32(end))
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(HymnSummary(
                catalog: catalog,
                number: textColumn(stmt, 0),
                title: cleanTitle(textColumn(stmt, 1))
            ))
        }
        return rows
    }

    func searchHymns(keyword: String, catalog: Int? = nil, limit: Int = 100) -> [HymnSearchResult] {
        let term = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }

        var rows = [HymnSearchResult]()
        var seen = Set<String>()
        let hymnalCatalogClause = catalog == nil ? "" : "AND h.catalog=?"
        let chorusCatalogClause = catalog == nil ? "" : "AND c.catalog=?"
        let sql = """
        SELECT h.catalog, h.number, COALESCE(t.lyric, h.lyric) AS title,
               h.lyric AS excerpt, 0 AS source, h.article, CAST(h.serial AS INTEGER) AS row_order,
               CAST(h.number AS INTEGER) AS number_order
        FROM hymnal AS h
        LEFT JOIN hymnal AS t
          ON t.language=h.language AND t.catalog=h.catalog AND t.number=h.number
         AND CAST(t.serial AS INTEGER)=0
        WHERE h.language=? \(hymnalCatalogClause)
          AND CAST(h.serial AS INTEGER) > 0
          AND h.lyric LIKE ?
        UNION ALL
        SELECT c.catalog, c.number, COALESCE(t.lyric, '') AS title,
               c.chorus AS excerpt, 1 AS source, c.article, CAST(c.serial AS INTEGER) AS row_order,
               CAST(c.number AS INTEGER) AS number_order
        FROM hchorus AS c
        LEFT JOIN hymnal AS t
          ON t.language=c.language AND t.catalog=c.catalog AND t.number=c.number
         AND CAST(t.serial AS INTEGER)=0
        WHERE c.language=? \(chorusCatalogClause)
          AND c.chorus LIKE ?
        ORDER BY 1, 8, 2, 5, 6, 7
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }

        var bindIndex: Int32 = 1
        sqlite3_bind_text(stmt, bindIndex, language, -1, transient)
        bindIndex += 1
        if let catalog {
            sqlite3_bind_int(stmt, bindIndex, Int32(catalog))
            bindIndex += 1
        }
        let pattern = "%\(term)%"
        sqlite3_bind_text(stmt, bindIndex, pattern, -1, transient)
        bindIndex += 1
        sqlite3_bind_text(stmt, bindIndex, language, -1, transient)
        bindIndex += 1
        if let catalog {
            sqlite3_bind_int(stmt, bindIndex, Int32(catalog))
            bindIndex += 1
        }
        sqlite3_bind_text(stmt, bindIndex, pattern, -1, transient)
        bindIndex += 1
        sqlite3_bind_int(stmt, bindIndex, Int32(limit * 10))

        while sqlite3_step(stmt) == SQLITE_ROW && rows.count < limit {
            let summary = HymnSummary(
                catalog: Int(sqlite3_column_int(stmt, 0)),
                number: textColumn(stmt, 1),
                title: cleanTitle(textColumn(stmt, 2))
            )
            guard !seen.contains(summary.id) else { continue }
            seen.insert(summary.id)
            rows.append(HymnSearchResult(
                summary: summary,
                excerpt: matchedExcerpt(textColumn(stmt, 3), term: term)
            ))
        }
        return rows
    }

    func adjacentHymn(catalog: Int, number: String, direction: Int) -> HymnSummary? {
        if let appendix = appendixNumber(number), catalog == 1 {
            let nextAppendix = appendix + direction
            if (1...6).contains(nextAppendix) {
                let nextNumber = "附\(nextAppendix)"
                return HymnSummary(catalog: catalog, number: nextNumber, title: getTitle(catalog: catalog, number: nextNumber))
            }
            if direction < 0 {
                return regularBoundaryHymn(catalog: catalog, ascending: false)
            }
            return nil
        }

        guard let current = Int(number) else { return nil }
        if let next = regularAdjacentHymn(catalog: catalog, number: current, direction: direction) {
            return next
        }
        if direction > 0, catalog == 1 {
            let nextNumber = "附1"
            return HymnSummary(catalog: catalog, number: nextNumber, title: getTitle(catalog: catalog, number: nextNumber))
        }
        return nil
    }

    private func regularAdjacentHymn(catalog: Int, number: Int, direction: Int) -> HymnSummary? {
        let comparison = direction > 0 ? ">" : "<"
        let sort = direction > 0 ? "ASC" : "DESC"
        let sql = """
        SELECT number, lyric
        FROM hymnal
        WHERE language=? AND catalog=? AND CAST(serial AS INTEGER)=0
          AND number NOT LIKE '附%' AND CAST(number AS INTEGER) \(comparison) ?
        ORDER BY CAST(number AS INTEGER) \(sort)
        LIMIT 1
        """
        return firstSummary(sql: sql, catalog: catalog, intValue: number)
    }

    private func regularBoundaryHymn(catalog: Int, ascending: Bool) -> HymnSummary? {
        let sort = ascending ? "ASC" : "DESC"
        let sql = """
        SELECT number, lyric
        FROM hymnal
        WHERE language=? AND catalog=? AND CAST(serial AS INTEGER)=0
          AND number NOT LIKE '附%'
        ORDER BY CAST(number AS INTEGER) \(sort)
        LIMIT 1
        """
        return firstSummary(sql: sql, catalog: catalog, intValue: nil)
    }

    private func firstSummary(sql: String, catalog: Int, intValue: Int?) -> HymnSummary? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, language, -1, transient)
        sqlite3_bind_int(stmt, 2, Int32(catalog))
        if let intValue {
            sqlite3_bind_int(stmt, 3, Int32(intValue))
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return HymnSummary(
            catalog: catalog,
            number: textColumn(stmt, 0),
            title: cleanTitle(textColumn(stmt, 1))
        )
    }

    private func appendixNumber(_ number: String) -> Int? {
        guard number.hasPrefix("附") else { return nil }
        return Int(number.dropFirst())
    }

    private func textColumn(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: value)
    }

    private func cleanTitle(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\\n", with: "\n")
            .components(separatedBy: "\n")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func matchedExcerpt(_ raw: String, term: String) -> String {
        let lines = raw.replacingOccurrences(of: "\\n", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return "" }

        let matchIndex = lines.firstIndex {
            $0.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        } ?? 0
        let startIndex = min(matchIndex, max(0, lines.count - 4))
        let endIndex = min(lines.count, startIndex + 4)
        return lines[startIndex..<endIndex].joined(separator: "\n")
    }
}
