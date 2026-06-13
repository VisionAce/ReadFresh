//
//  HymnImageProvider.swift
//  ReadFreshTest
//

import Foundation

struct HymnImageProvider {
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

    static func url(for imageName: String) -> URL? {
        let parts = imageName.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return Bundle.main.url(forResource: parts[0], withExtension: parts[1], subdirectory: "HymnImages")
    }

    private static func mainImageNames(number rawNumber: String) -> [String] {
        guard let number = mainImageNumber(rawNumber),
              let start = mainStartIndex(for: number) else {
            return []
        }
        let end: Int
        if number < 786, let nextStart = mainStartIndex(for: number + 1) {
            end = nextStart - 1
        } else {
            end = 818
        }
        return imageNames(prefix: "d", start: start, end: end)
    }

    private static func supplementImageNames(number rawNumber: String) -> [String] {
        guard let number = Int(rawNumber),
              let start = supplementStartIndex(for: number) else {
            return []
        }
        let end: Int
        if let nextNumber = nextSupplementNumber(after: number),
           let nextStart = supplementStartIndex(for: nextNumber) {
            end = max(start, nextStart - 1)
        } else {
            end = 566
        }
        return imageNames(prefix: "b", start: start, end: end)
    }

    private static func childrenImageNames(number rawNumber: String) -> [String] {
        guard let number = Int(rawNumber) else { return [] }
        let index = number + 4
        guard (0...160).contains(index) else { return [] }
        return imageName(prefix: "n", index: index).map { [$0] } ?? []
    }

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
        case 1...128:
            return number + 16
        case 129...152:
            return number + 17
        case 153...188:
            return number + 21
        case 189...310:
            return number + 22
        case 311...316:
            return number + 23
        case 317...388:
            return number + 24
        case 389...465:
            return number + 26
        case 466...469:
            return number + 28
        case 470...717:
            return number + 29
        case 718...758:
            return number + 30
        case 759...776:
            return number + 31
        case 777...786:
            return number + 32
        default:
            return nil
        }
    }

    // Ported from new.apk com.example.song.maintouch:
    // sel="xb", skip=19, then setSelection(nui) after these number corrections.
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
        case 37:
            return 101
        case 150:
            return 201
        case 258:
            return 301
        case 349:
            return 401
        case 470:
            return 501
        case 543:
            return 601
        case 629:
            return 701
        case 762:
            return 801
        case 880:
            return 901
        case 930:
            return 1001
        default:
            return nil
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
