//
//  HymnView.swift
//  ReadFreshTest
//

import SwiftUI

enum HymnCatalog: Int, CaseIterable {
    case main = 1
    case supplement = 2
    case children = 3

    var displayName: String {
        switch self {
        case .main: return "大本詩歌"
        case .supplement: return "補充本"
        case .children: return "兒童詩歌"
        }
    }

    var maxNumber: Int {
        switch self {
        case .main: return 780
        case .supplement: return 1005
        case .children: return 1232
        }
    }
}

struct HymnView: View {
    @State private var catalog: HymnCatalog = .main
    @State private var inputNumber = ""
    @State private var hymnRows: [HymnDB.HymnRow] = []
    @State private var chorusRows: [HymnDB.ChorusRow] = []
    @State private var searched = false
    @State private var notFound = false
    @FocusState private var inputFocused: Bool

    private var colorData = ColorData()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Catalog picker
                Picker("詩歌本", selection: $catalog) {
                    ForEach(HymnCatalog.allCases, id: \.self) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: catalog) {
                    reset()
                }

                // Number input
                HStack(spacing: 12) {
                    TextField("詩歌編號（1–\(catalog.maxNumber)）", text: $inputNumber)
                        .keyboardType(.numberPad)
                        .focused($inputFocused)
                        .font(.title2)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onChange(of: inputNumber) {
                            // strip non-digits and enforce max length
                            let digits = inputNumber.filter(\.isNumber)
                            inputNumber = String(digits.prefix(4))
                        }

                    Button(action: search) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(colorData.themeColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(inputNumber.isEmpty)
                }
                .padding(.horizontal)

                Divider().padding(.top)

                // Lyrics display
                if notFound {
                    ContentUnavailableView(
                        "找不到詩歌 \(inputNumber)",
                        systemImage: "music.note",
                        description: Text("\(catalog.displayName) 沒有第 \(inputNumber) 首")
                    )
                } else if hymnRows.isEmpty && !searched {
                    Spacer()
                    Text("輸入詩歌編號點歌")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    LyricsScrollView(rows: hymnRows, chorusRows: chorusRows)
                }
            }
            .navigationTitle("詩歌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { inputFocused = false }
                }
            }
        }
    }

    private func search() {
        inputFocused = false
        guard let num = Int(inputNumber), num > 0, num <= catalog.maxNumber else {
            notFound = true
            hymnRows = []
            searched = true
            return
        }
        let rows = HymnDB.shared.getHymn(catalog: catalog.rawValue, number: inputNumber)
        if rows.isEmpty {
            notFound = true
            hymnRows = []
        } else {
            notFound = false
            hymnRows = rows
            chorusRows = HymnDB.shared.getChorus(catalog: catalog.rawValue, number: inputNumber)
        }
        searched = true
    }

    private func reset() {
        inputNumber = ""
        hymnRows = []
        chorusRows = []
        searched = false
        notFound = false
    }
}

private struct LyricsScrollView: View {
    let rows: [HymnDB.HymnRow]
    let chorusRows: [HymnDB.ChorusRow]

    // group rows by article
    private var articles: [(Int, [HymnDB.HymnRow])] {
        var dict = [(Int, [HymnDB.HymnRow])]()
        var seen = [Int: Int]()
        for row in rows {
            if let idx = seen[row.article] {
                dict[idx].1.append(row)
            } else {
                seen[row.article] = dict.count
                dict.append((row.article, [row]))
            }
        }
        return dict
    }

    // header row (article=1, serial=0)
    private var header: String? {
        rows.first(where: { $0.article == 1 && $0.serial == 0 }).map { formatLyric($0.lyric) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let h = header {
                    Text(h)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                ForEach(articles, id: \.0) { article, articleRows in
                    let verseRows = articleRows.filter { $0.serial > 0 }
                    if !verseRows.isEmpty {
                        VerseView(article: article, rows: verseRows)
                        // show chorus after each verse that falls within chorus range
                        ForEach(chorusRows.filter { $0.begin <= article && $0.end >= article }, id: \.begin) { c in
                            ChorusView(text: formatLyric(c.chorus))
                        }
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }
}

private struct VerseView: View {
    let article: Int
    let rows: [HymnDB.HymnRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(article).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Text(formatLyric(row.lyric))
                    .font(.body)
                    .padding(.horizontal)
            }
        }
    }
}

private struct ChorusView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.body)
                .italic()
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.leading, 12)
        }
    }
}

private func formatLyric(_ raw: String) -> String {
    raw.replacingOccurrences(of: "\\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}
