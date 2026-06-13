//
//  HymnView.swift
//  ReadFreshTest
//

import SwiftUI
import UIKit

enum HymnCatalog: Int, CaseIterable, Codable {
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

    var shortName: String {
        switch self {
        case .main: return "大本"
        case .supplement: return "補充"
        case .children: return "兒童"
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

private enum HymnMode: String, CaseIterable {
    case dial = "點歌"
    case directory = "目錄"
    case search = "搜尋"
}

private enum HymnSearchFilter: String, CaseIterable {
    case all = "全部"
    case main = "大本"
    case supplement = "補充"
    case children = "兒童"

    var catalog: HymnCatalog? {
        switch self {
        case .all: return nil
        case .main: return .main
        case .supplement: return .supplement
        case .children: return .children
        }
    }
}

private let hymnBottomBlankSpace: CGFloat = 56

struct HymnView: View {
    let isActive: Bool

    @State private var mode: HymnMode = .dial
    @State private var catalog: HymnCatalog = .main
    @State private var inputNumber = ""
    @State private var currentSummary: HymnDB.HymnSummary?
    @State private var hymnRows: [HymnDB.HymnRow] = []
    @State private var chorusRows: [HymnDB.ChorusRow] = []
    @State private var searched = false
    @State private var notFound = false
    @State private var showHymnNotFoundAlert = false
    @State private var hymnNotFoundMessage = ""
    @State private var searchText = ""
    @State private var searchResults: [HymnDB.HymnSearchResult] = []
    @State private var searchFilter: HymnSearchFilter = .all
    @State private var navigationPath = NavigationPath()
    @FocusState private var searchFocused: Bool

    private var colorData = ColorData()

    init(isActive: Bool) {
        self.isActive = isActive
    }

    private var filteredSearchResults: [HymnDB.HymnSearchResult] {
        guard let catalog = searchFilter.catalog else { return searchResults }
        return searchResults.filter { $0.summary.catalog == catalog.rawValue }
    }

    private var searchResultSections: [(catalog: HymnCatalog, results: [HymnDB.HymnSearchResult])] {
        HymnCatalog.allCases.compactMap { catalog in
            let results = filteredSearchResults.filter { $0.summary.catalog == catalog.rawValue }
            return results.isEmpty ? nil : (catalog, results)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                Picker("功能", selection: $mode) {
                    ForEach(HymnMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                .onChange(of: mode) { oldValue, newValue in
                    if oldValue == .search && newValue != .search {
                        clearSearchState()
                    }
                }

                if mode == .dial || mode == .directory {
                    catalogPicker
                }

                Divider()

                Group {
                    switch mode {
                    case .dial:
                        dialView
                    case .directory:
                        directoryView
                    case .search:
                        searchView
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: hymnBottomBlankSpace)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(navigationPath.isEmpty ? .hidden : .visible, for: .navigationBar)
            .navigationDestination(for: HymnDB.HymnSummary.self) { summary in
                HymnDetailView(initialSummary: summary)
            }
            .onChange(of: navigationPath.count) { oldValue, newValue in
                if oldValue > 0 && newValue == 0 {
                    clearDialState()
                }
            }
            .alert("查無此歌", isPresented: $showHymnNotFoundAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(hymnNotFoundMessage)
            }
            .onChange(of: isActive) { _, newValue in
                if !newValue {
                    resetHymnPage()
                }
            }
        }
    }

    private var catalogPicker: some View {
        Picker("詩歌本", selection: $catalog) {
            ForEach(HymnCatalog.allCases, id: \.self) { catalog in
                Text(catalog.displayName).tag(catalog)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .onChange(of: catalog) {
            clearDialState()
            searchResults = []
        }
    }

    private var dialView: some View {
        ScrollView {
            VStack(spacing: 14) {
                numberDisplay
                keypad
            }
            .padding(.bottom, hymnBottomBlankSpace)
        }
    }

    private var numberDisplay: some View {
        VStack(spacing: 8) {
            HStack {
                Label(catalog.displayName, systemImage: "books.vertical")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(inputNumber.isEmpty ? " " : inputNumber)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var keypad: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "附", "0", "delete.left"]

        return VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(keys, id: \.self) { key in
                    Button {
                        handleKey(key)
                    } label: {
                        if key == "delete.left" {
                            Image(systemName: key)
                                .font(.title2.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        } else {
                            Text(key)
                                .font(.title2.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(key == "附" && catalog != .main)
                }
            }

            HStack(spacing: 10) {
                Button {
                    clearDialState()
                } label: {
                    Label("清除", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.bordered)

                Button(action: requestHymn) {
                    Label("點歌", systemImage: "music.note")
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(colorData.themeColor)
                .disabled(inputNumber.isEmpty)
            }
        }
        .padding(.horizontal)
    }

    private var directoryView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(HymnDB.shared.getDirectory(catalog: catalog.rawValue, level: 1)) { group in
                    DirectoryGroupView(group: group, onSelect: loadSummary)
                    Divider()
                }
            }
        }
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("搜尋全部詩歌歌詞或副歌", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit(performSearch)

                Button(action: performSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(colorData.themeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            Picker("搜尋範圍", selection: $searchFilter) {
                ForEach(HymnSearchFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom)

            if searchResults.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "輸入關鍵字" : "沒有搜尋結果",
                    systemImage: "magnifyingglass",
                    description: Text("搜尋範圍是全部詩歌資料庫")
                )
            } else if filteredSearchResults.isEmpty {
                ContentUnavailableView(
                    "沒有搜尋結果",
                    systemImage: "magnifyingglass",
                    description: Text("\(searchFilter.rawValue)沒有符合的歌詞")
                )
            } else {
                List {
                    ForEach(searchResultSections, id: \.catalog) { section in
                        Section(section.catalog.displayName) {
                            ForEach(section.results) { result in
                                NavigationLink(value: result.summary) {
                                    HymnSearchResultRow(result: result)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func handleKey(_ key: String) {
        notFound = false
        switch key {
        case "delete.left":
            if !inputNumber.isEmpty {
                inputNumber.removeLast()
            }
        case "附":
            if inputNumber.hasPrefix("附") {
                inputNumber.removeFirst()
            } else {
                inputNumber = "附" + inputNumber.filter(\.isNumber).prefix(1)
            }
        default:
            appendDigit(key)
        }
    }

    private func appendDigit(_ digit: String) {
        if inputNumber.hasPrefix("附") {
            let currentDigits = inputNumber.dropFirst().filter(\.isNumber)
            inputNumber = "附" + String((String(currentDigits) + digit).prefix(1))
        } else {
            inputNumber = String((inputNumber.filter(\.isNumber) + digit).prefix(4))
        }
    }

    private func requestHymn() {
        let number = normalizedInput()
        guard isValid(number: number, catalog: catalog) else {
            showHymnNotFound(catalog: catalog, number: number)
            searched = true
            return
        }
        load(catalog: catalog, number: number, navigate: true)
    }

    private func loadSummary(_ summary: HymnDB.HymnSummary) {
        guard let targetCatalog = HymnCatalog(rawValue: summary.catalog) else { return }
        catalog = targetCatalog
        load(catalog: targetCatalog, number: summary.number, title: summary.title, navigate: true)
        mode = .dial
    }

    private func load(catalog: HymnCatalog, number: String, title: String? = nil, navigate: Bool = false) {
        let rows = HymnDB.shared.getHymn(catalog: catalog.rawValue, number: number)
        if rows.isEmpty {
            showHymnNotFound(catalog: catalog, number: number)
            hymnRows = []
            chorusRows = []
            currentSummary = nil
        } else {
            let summaryTitle = title?.isEmpty == false ? title! : HymnDB.shared.getTitle(catalog: catalog.rawValue, number: number)
            let summary = HymnDB.HymnSummary(catalog: catalog.rawValue, number: number, title: summaryTitle)
            notFound = false
            inputNumber = number
            currentSummary = summary
            hymnRows = rows
            chorusRows = HymnDB.shared.getChorus(catalog: catalog.rawValue, number: number)
            if navigate {
                navigationPath.append(summary)
            }
        }
        searched = true
    }

    private func showHymnNotFound(catalog: HymnCatalog, number: String) {
        notFound = true
        let displayNumber = number.isEmpty ? inputNumber : number
        hymnNotFoundMessage = "\(catalog.displayName) 沒有第 \(displayNumber) 首"
        showHymnNotFoundAlert = true
    }

    private func clearDialState() {
        inputNumber = ""
        currentSummary = nil
        hymnRows = []
        chorusRows = []
        searched = false
        notFound = false
        showHymnNotFoundAlert = false
        hymnNotFoundMessage = ""
    }

    private func performSearch() {
        searchFocused = false
        searchResults = HymnCatalog.allCases.flatMap { catalog in
            HymnDB.shared.searchHymns(keyword: searchText, catalog: catalog.rawValue)
        }
    }

    private func clearSearchState() {
        searchFocused = false
        searchText = ""
        searchResults = []
        searchFilter = .all
    }

    private func resetHymnPage() {
        navigationPath = NavigationPath()
        mode = .dial
        catalog = .main
        clearDialState()
        clearSearchState()
    }

    private func normalizedInput() -> String {
        let trimmed = inputNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("附") {
            return "附" + trimmed.dropFirst().filter(\.isNumber)
        }
        return trimmed.filter(\.isNumber)
    }

    private func isValid(number: String, catalog: HymnCatalog) -> Bool {
        if catalog == .main, number.hasPrefix("附"), let appendix = Int(number.dropFirst()) {
            return (1...6).contains(appendix)
        }
        guard let value = Int(number) else { return false }
        return value > 0 && value <= catalog.maxNumber
    }

}

private struct DirectoryGroupView: View {
    let group: HymnDB.DirectoryEntry
    let onSelect: (HymnDB.HymnSummary) -> Void
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(HymnDB.shared.getDirectory(catalog: group.catalog, level: 2, groupID: group.groupID)) { section in
                    DirectorySectionView(section: section, onSelect: onSelect)
                }
            }
            .padding(.leading, 12)
        } label: {
            Text(group.title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

private struct DirectorySectionView: View {
    let section: HymnDB.DirectoryEntry
    let onSelect: (HymnDB.HymnSummary) -> Void
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(HymnDB.shared.getHymns(catalog: section.catalog, begin: section.begin, end: section.end)) { hymn in
                    Button {
                        onSelect(hymn)
                    } label: {
                        HymnSummaryRow(summary: hymn)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
            .padding(.leading, 10)
        } label: {
            HStack {
                Text(section.title)
                Spacer()
                Text("\(section.begin)-\(section.end)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

private struct HymnSummaryRow: View {
    let summary: HymnDB.HymnSummary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(catalogName(summary.catalog)) \(summary.number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)

            Text(summary.title.isEmpty ? "詩歌 \(summary.number)" : summary.title)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

private struct HymnSearchResultRow: View {
    let result: HymnDB.HymnSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HymnSummaryRow(summary: result.summary)

            Text(formatLyric(result.excerpt))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

private enum HymnDisplayMode: String, CaseIterable {
    case image = "圖片"
    case text = "文字"
}

private struct HymnDetailView: View {
    @State private var summary: HymnDB.HymnSummary
    @State private var rows: [HymnDB.HymnRow] = []
    @State private var chorusRows: [HymnDB.ChorusRow] = []
    @State private var imageNames: [String] = []
    @State private var displayMode: HymnDisplayMode = .image

    init(initialSummary: HymnDB.HymnSummary) {
        _summary = State(initialValue: initialSummary)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !imageNames.isEmpty {
                Picker("顯示", selection: $displayMode) {
                    ForEach(HymnDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()
            }

            if displayMode == .image, !imageNames.isEmpty {
                HymnImageScrollView(imageNames: imageNames)
            } else {
                ScrollView {
                    LyricsScrollView(summary: summary, rows: rows, chorusRows: chorusRows)
                }
            }
        }
        .navigationTitle("\(catalogName(summary.catalog)) \(summary.number)")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: hymnBottomBlankSpace)
        }
        .onAppear(perform: load)
    }

    private func load() {
        rows = HymnDB.shared.getHymn(catalog: summary.catalog, number: summary.number)
        chorusRows = HymnDB.shared.getChorus(catalog: summary.catalog, number: summary.number)
        imageNames = HymnImageProvider.imageNames(for: summary)
        displayMode = imageNames.isEmpty ? .text : .image
    }
}

private struct HymnImageScrollView: View {
    let imageNames: [String]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(imageNames, id: \.self) { imageName in
                    if let url = HymnImageProvider.url(for: imageName),
                       let image = UIImage(contentsOfFile: url.path) {
                        ZoomableHymnImage(image: image)
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }
}

private struct ZoomableHymnImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(Rectangle())
            .contentShape(Rectangle())
            .gesture(zoomGesture)
            .simultaneousGesture(panGesture)
            .onTapGesture(count: 2, perform: toggleZoom)
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(baseScale * value, 1), 5)
                if scale == 1 {
                    offset = .zero
                }
            }
            .onEnded { _ in
                if scale <= 1.05 {
                    resetZoom()
                } else {
                    baseScale = scale
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > 1 else { return }
                baseOffset = offset
            }
    }

    private func toggleZoom() {
        if scale > 1 {
            resetZoom()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                scale = 2
                baseScale = 2
                offset = .zero
                baseOffset = .zero
            }
        }
    }

    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            scale = 1
            baseScale = 1
            offset = .zero
            baseOffset = .zero
        }
    }
}

private struct LyricsScrollView: View {
    let summary: HymnDB.HymnSummary
    let rows: [HymnDB.HymnRow]
    let chorusRows: [HymnDB.ChorusRow]
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    @AppStorage(UserDefaultsDataKeys.lineSpacingSize) private var lineSpacingSize: Double = 8.0

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

    private var header: String {
        if !summary.title.isEmpty {
            return summary.title
        }
        return rows.first(where: { $0.serial == 0 }).map { formatLyric($0.lyric) } ?? ""
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if !header.isEmpty {
                Text(header)
                    .font(.system(size: fontSize, weight: .semibold))
                    .lineSpacing(lineSpacingSize)
                    .foregroundStyle(.primary)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            ForEach(articles, id: \.0) { section in
                let article = section.0
                let articleRows = section.1
                let verseRows = articleRows.filter { $0.serial > 0 }

                if !verseRows.isEmpty {
                    ForEach(verseRows, id: \.serial) { row in
                        VerseView(
                            number: row.serial,
                            text: formatLyric(row.lyric),
                            fontSize: fontSize,
                            lineSpacingSize: lineSpacingSize
                        )

                        ForEach(Array(chorusRows.filter { chorus in
                            chorus.article == article && chorus.begin <= row.serial && chorus.end >= row.serial
                        }.enumerated()), id: \.offset) { _, chorus in
                            ChorusView(
                                text: formatLyric(chorus.chorus),
                                fontSize: fontSize,
                                lineSpacingSize: lineSpacingSize
                            )
                        }
                    }
                }
            }
        }
        .padding(.bottom, 32)
        .foregroundStyle(.primary)
    }
}

private struct VerseView: View {
    let number: Int
    let text: String
    let fontSize: Double
    let lineSpacingSize: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(number).")
                .font(.system(size: max(12, fontSize - 4), weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal)

            SelectableText(
                text: text,
                fontSize: fontSize,
                lineSpacing: lineSpacingSize
            )
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.primary)
            .padding(.horizontal)
                
        }
    }
}

private struct ChorusView: View {
    let text: String
    let fontSize: Double
    let lineSpacingSize: Double

    var body: some View {
        Text(text)
            .font(.system(size: fontSize))
            .lineSpacing(lineSpacingSize)
            .italic()
            .foregroundStyle(.primary)
            .padding(.horizontal)
    }
}

private func formatLyric(_ raw: String) -> String {
    raw.replacingOccurrences(of: "\\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

private func catalogName(_ catalog: Int) -> String {
    HymnCatalog(rawValue: catalog)?.shortName ?? "詩歌"
}
