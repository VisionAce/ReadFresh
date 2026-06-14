//
//  HymnImageProvider.swift
//  ReadFreshTest
//
//  Created by Gemini on 2026/6/14.
//

import Foundation

struct HymnImageProvider {
    
    // =========================================================================
    // 🌟 例外頁面終點對照表 (解決圖片增加、編號未增加，或兩首詩歌共享同一頁實體歌譜的問題)
    // Key: 詩歌編號 (Int), Value: 強制指定的實體圖片結束序號 (Int)
    // =========================================================================
    
    // 如果未來測試發現大本詩歌有共享圖片或漏頁狀況，在此直接追加即可
    // 例如：30: 46 (代表大本30首強制結束在 d46)
    private static let mainEndOverrides: [Int: Int] = [:]
    
    private static let supplementEndOverrides: [Int: Int] = [
        31: 52, // 🌟 補充本 31 首：常規公式算出來是 51，我們強制讓它結束在 52，使其包含 b51, b52（完美與32首共享b52）
        34: 56,
        144: 103,
        251: 161,
        253: 163,
        330: 200,
        332: 202,
        334: 204,
        336: 206,
        432: 251,
        438: 257,
        445: 265,
        448: 268,
        450: 271,
        454: 277,
        462: 285,
        466: 289,
        537: 333,
        540: 337,
        542: 340,
        621: 362,
        857: 491,
        861: 495,
        865: 499,
        867: 501,
        871: 505,
        917: 534,
        920: 537,
        922: 540,
        925: 543
    ]
    
    // =========================================================================
    // 核心入口方法
    // =========================================================================
    static func imageNames(for summary: HymnDB.HymnSummary) -> [String] {
        switch HymnCatalog(rawValue: summary.catalog) {
        case .main:
            return mainImageNames(number: summary.number)
        case .supplement:
            return supplementImageNames(number: summary.number)
        case .children:
            return childrenImageNames(number: summary.number)
        case .none:
            return []
        }
    }

    /// 取得檔案實際的專案 Bundle URL
    static func url(for imageName: String) -> URL? {
        let parts = imageName.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return Bundle.main.url(forResource: parts[0], withExtension: parts[1], subdirectory: "HymnImages")
    }

    // =========================================================================
    // 大本詩歌圖片處理邏輯
    // =========================================================================
    private static func mainImageNames(number rawNumber: String) -> [String] {
        guard let number = mainImageNumber(rawNumber),
              let start = mainStartIndex(for: number) else {
            return []
        }
        
        let end: Int
        // 🌟 優先檢查大本詩歌有沒有手動指定的例外終點
        if let overrideEnd = mainEndOverrides[number] {
            end = overrideEnd
        } else if number < 786, let nextStart = mainStartIndex(for: number + 1) {
            end = nextStart - 1
        } else {
            end = 818
        }
        return imageNames(prefix: "d", start: start, end: end)
    }

    // =========================================================================
    // 補充本詩歌圖片處理邏輯
    // =========================================================================
    private static func supplementImageNames(number rawNumber: String) -> [String] {
        guard let number = Int(rawNumber),
              let start = supplementStartIndex(for: number) else {
            return []
        }
        
        let end: Int
        // 🌟 優先檢查補充本有沒有手動指定的例外終點
        if let overrideEnd = supplementEndOverrides[number] {
            end = overrideEnd
        } else if let nextNumber = nextSupplementNumber(after: number),
                  let nextStart = supplementStartIndex(for: nextNumber) {
            end = max(start, nextStart - 1)
        } else {
            end = 566
        }
        return imageNames(prefix: "b", start: start, end: end)
    }

    // =========================================================================
    // 兒童詩歌圖片處理邏輯
    // =========================================================================
    private static func childrenImageNames(number rawNumber: String) -> [String] {
        guard let number = Int(rawNumber) else { return [] }
        let index = number + 4
        guard (0...160).contains(index) else { return [] }
        return imageName(prefix: "n", index: index).map { [$0] } ?? []
    }

    // =========================================================================
    // 工具輔助與索引補償對照方法 (由原 APK 邏輯移植)
    // =========================================================================
    private static func mainImageNumber(_ number: String) -> Int? {
        if number.hasPrefix("附"), let appendix = Int(number.dropFirst()), (1...6).contains(appendix) {
            return 780 + appendix
        }
        guard let value = Int(number), (1...780).contains(value) else { return nil }
        return value
    }

    private static func mainStartIndex(for number: Int) -> Int? {
        guard (1...786).contains(number) else { return nil }
        switch number {
        case 1...128: return number + 16
        case 129...152: return number + 17
        case 153...188: return number + 21
        case 189...310: return number + 22
        case 311...316: return number + 23
        case 317...388: return number + 24
        case 389...465: return number + 26
        case 466...469: return number + 28
        case 470...717: return number + 29
        case 718...758: return number + 30
        case 759...776: return number + 31
        case 777...786: return number + 32
        default: return nil
        }
    }

    private static func supplementStartIndex(for number: Int) -> Int? {
        let skip = 19
        switch number {
        case 1...37:
            return number + skip
                + (number > 9 ? 1 : 0)
                + (number > 32 ? 1 : 0)
        case 101...150:
            return number - 42
                + (number > 148 ? 1 : 0)
        case 201...258:
            return number - 91
                + (number > 257 ? 2 : 0)
        case 301...349:
            return number - 131
        case 401...470:
            return number - 182
                + countThresholds(number, [440, 449, 451, 453, 468, 469])
        case 501...543:
            return number - 206
                + countThresholds(number, [512, 538, 541])
        case 601...629:
            return number - 260
        case 701...762:
            return number - 331
                + (number > 702 ? 2 : 0)
                - (number == 754 ? 1 : 0)
        case 801...880:
            return number - 367
                + (number > 875 ? 1 : 0)
        case 901...930:
            return number - 386
                + (number > 909 ? 2 : 0)
                + (number > 921 ? 1 : 0)
                + (number > 926 ? 1 : 0)
        case 1001...1005:
            return number - 452
        default:
            return nil
        }
    }

    private static func nextSupplementNumber(after number: Int) -> Int? {
        switch number {
        case 1..<37, 101..<150, 201..<258, 301..<349, 401..<470,
             501..<543, 601..<629, 701..<762, 801..<880, 901..<930,
             1001..<1005:
            return number + 1
        case 37: return 101
        case 150: return 201
        case 258: return 301
        case 349: return 401
        case 470: return 501
        case 543: return 601
        case 629: return 701
        case 762: return 801
        case 880: return 901
        case 930: return 1001
        default: return nil
        }
    }

    private static func countThresholds(_ number: Int, _ thresholds: [Int]) -> Int {
        thresholds.reduce(0) { count, threshold in
            count + (number > threshold ? 1 : 0)
        }
    }

    private static func imageNames(prefix: String, start: Int, end: Int) -> [String] {
        guard end >= start else { return [] }
        return (start...end).compactMap { imageName(prefix: prefix, index: $0) }
    }

    private static func imageName(prefix: String, index: Int) -> String? {
        for ext in ["png", "jpg"] {
            let name = "\(prefix)\(index).\(ext)"
            if url(for: name) != nil {
                return name
            }
        }
        return nil
    }
}
