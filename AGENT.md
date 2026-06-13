# ReadFresh Agent Notes

This file is for future Codex/agent sessions. It documents what this repo is for, where the important code lives, and the implementation details that are easy to forget.

## Project Purpose

ReadFresh is a SwiftUI iOS app for daily Christian reading content. The original app has tabs for this week's content, past content, hymns, and settings. The app uses Firebase/Firestore for reading data and a bundled SQLite database plus image assets for the hymn feature.

The active iOS project is:

- Project: `iOS-App/ReadFreshTest/ReadFreshTest.xcodeproj`
- Scheme: `ReadFreshTest`
- Main app source: `iOS-App/ReadFreshTest/ReadFreshTest`
- Main entry: `ReadFreshTestApp.swift`
- Root UI: `ContentView.swift`
- Custom tabs: `CustomTabBar/Model/Tab.swift`

Build verification command:

```sh
xcodebuild -quiet -project iOS-App/ReadFreshTest/ReadFreshTest.xcodeproj -scheme ReadFreshTest -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Use `git diff --check -- <files>` before finalizing edits.

## App Structure

`ContentView.swift` owns the root `TabView` and custom bottom tab bar. The app tabs are:

- `thisWeek`: `MessageView()`
- `pastWeek`: `PastMessage()`
- `hymn`: `HymnView(isActive: activeTab == .hymn)`
- `setting`: `SettingView(reads: reads)`

`ContentView` controls dark mode using:

- `UserDefaultsDataKeys.toggleDarkMode`
- `UserDefaultsDataKeys.activateDarkMode`

It applies:

```swift
.preferredColorScheme(activateDarkMode ? .dark : .light)
```

When adding text color in hymn/detail views, prefer `.primary` unless the user explicitly wants a fixed color. `.primary` is black in light mode and white in dark mode.

## Settings

`SettingView.swift` stores reading text settings:

- `UserDefaultsDataKeys.fontSize`, default `18.0`
- `UserDefaultsDataKeys.lineSpacingSize`, default `8.0`

The hymn text detail page must respect these same settings for font size and line spacing.

## Hymn Feature Overview

The hymn feature lives mainly in:

- `HymnView.swift`: UI, navigation, keypad, directory, search, detail, image/text display
- `HymnDB.swift`: SQLite access for `hymns.db`
- `HymnImageProvider.swift`: mapping hymn numbers to bundled image files
- `hymns.db`: bundled SQLite database
- `HymnImages/`: bundled image assets for hymn pages

Current hymn UI modes:

- `點歌`
- `目錄`
- `搜尋`

There is intentionally no playlist/favorites feature now. All previous `hymnPlaylist`, "最愛", "播放清單", heart, plus/checkmark playlist buttons, and playlist/favorite tabs were removed. Do not reintroduce them unless explicitly asked.

### Hymn Page Reset Behavior

`ContentView` passes `isActive` into `HymnView`. When `activeTab` changes away from `.hymn`, `HymnView` resets all hymn page state:

- returns to `點歌`
- catalog resets to `.main`
- clears input number and currently loaded hymn
- clears search text/results/filter
- clears alert state
- clears `NavigationPath`, so detail closes

When switching from search to another hymn sub-mode (`點歌` or `目錄`), search text/results/filter are cleared.

When navigating from search results into hymn detail and then back, search is preserved because the hymn tab and mode did not change.

### Catalog Values

`HymnCatalog` values:

- `.main = 1`: 大本詩歌, max regular number `780`, plus appendix `附1` through `附6`
- `.supplement = 2`: 補充本, max `1005`
- `.children = 3`: 兒童詩歌, max `1232`

`catalogName(_:)` returns compact labels: `大本`, `補充`, `兒童`.

### Dial / Keypad

The keypad supports digits plus `附` for main hymnal appendix hymns. `附` is disabled outside the main hymnal.

Input rules:

- regular hymn numbers are numeric, max 4 digits in UI
- appendix input is `附` plus one digit
- invalid or missing hymn shows an alert titled `查無此歌`
- there should be no message/card underneath the `點歌` button

### Directory

Directory mode uses `hdir` through `HymnDB.getDirectory`.

Hierarchy:

- level 1: top groups
- level 2: sections inside group
- selecting a hymn opens detail

### Search

Search UI:

- Text field searches all hymn lyrics/choruses.
- Filter picker has `全部 / 大本 / 補充 / 兒童`.
- Search is executed separately for all three catalogs, then grouped by catalog sections. This prevents results from one catalog hiding another catalog because of per-query limits.
- Results are displayed under sections: 大本詩歌, 補充本, 兒童詩歌.
- Each result shows the hymn number/title plus the matched lyric/chorus excerpt.

Search result excerpt behavior:

- excludes hymn title rows (`hymnal.serial = 0`)
- includes real lyrics and chorus rows
- must include the search keyword
- shows up to four lines, using reserved four-line UI height
- `HymnDB.matchedExcerpt` chooses four lines around the matched line, so the keyword is not hidden by earlier lines

### Detail Page

Detail navigation title should show the compact hymn id, e.g. `大本 1`.

Display modes:

- Defaults to `圖片` when images exist.
- Falls back to `文字` when no images exist.
- If images exist, a segmented control lets the user switch between `圖片` and `文字`.
- If no images exist, only text is shown.

Removed from detail and should stay removed unless explicitly requested:

- previous/next hymn controls
- open hymn button
- playlist/favorite button

Bottom spacing:

- `hymnBottomBlankSpace` is `56`
- views use a bottom safe area inset / bottom padding so the custom bottom tab bar does not cover content

Text detail:

- title is shown at the top of the text body
- verse text uses `UserDefaultsDataKeys.fontSize`
- line spacing uses `UserDefaultsDataKeys.lineSpacingSize`
- verse numbers are bold
- chorus is aligned with verse text, not indented
- text color uses `.primary`, so it is black in light mode and white in dark mode

Image detail:

- `HymnImageScrollView` loads images from `HymnImageProvider`
- each image is wrapped in `ZoomableHymnImage`
- supports pinch zoom, drag when zoomed, and double-tap toggle zoom
- images have a white background because the source hymn images are page scans

## hymns.db Details

SQLite database:

`iOS-App/ReadFreshTest/ReadFreshTest/hymns.db`

Important tables:

```sql
CREATE TABLE IF NOT EXISTS "hymnal" (
  "_id" INTEGER PRIMARY KEY NOT NULL,
  "language" TEXT NOT NULL,
  "catalog" INTEGER NOT NULL,
  "number" TEXT NOT NULL,
  "article" INTEGER NOT NULL,
  "serial" TEXT NOT NULL,
  "lyric" TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS "hchorus" (
  "_id" INTEGER PRIMARY KEY NOT NULL,
  "language" TEXT NOT NULL,
  "catalog" INTEGER NOT NULL,
  "number" TEXT NOT NULL,
  "article" INTEGER NOT NULL,
  "max" INTEGER NOT NULL,
  "serial" INTEGER NOT NULL,
  "begin" INTEGER NOT NULL,
  "end" INTEGER NOT NULL,
  "chorus" TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS "hdir" (
  "_id" INTEGER PRIMARY KEY NOT NULL,
  "language" TEXT,
  "catalog" INTEGER NOT NULL,
  "level" INTEGER NOT NULL,
  "dir" TEXT NOT NULL,
  "begin" INTEGER NOT NULL,
  "end" INTEGER NOT NULL,
  "group_id" INTEGER NOT NULL
);
```

All current queries use language `big5`.

Critical row semantics:

- `hymnal.article` is not the verse number.
- `hymnal.serial` is the verse/order within an article.
- `serial = 0` is the title/header row.
- `serial > 0` are real verse rows.
- For hymn 1, all rows have `article = 1`; title is `serial = 0`, verses are `serial = 1...6`.
- `serial` is stored as text, so always use `CAST(serial AS INTEGER)` when ordering or comparing numerically.

Chorus mapping:

- `hchorus.article` must match the hymn row's `article`.
- `hchorus.begin` and `hchorus.end` map to hymn `serial` ranges, not `article`.
- When rendering text, show chorus after a verse if:

```swift
chorus.article == article && chorus.begin <= row.serial && chorus.end >= row.serial
```

`HymnDB.swift` models:

- `HymnRow`: article, serial, lyric
- `ChorusRow`: article, begin, end, chorus
- `HymnSummary`: catalog, number, title, id is `catalog-number`
- `HymnSearchResult`: summary plus matched excerpt
- `DirectoryEntry`: hdir row

## Hymn Images

Image files are bundled under:

`iOS-App/ReadFreshTest/ReadFreshTest/HymnImages/`

`HymnImageProvider.swift` maps a `HymnSummary` to one or more file names. The images are looked up with:

```swift
Bundle.main.url(forResource: parts[0], withExtension: parts[1], subdirectory: "HymnImages")
```

Naming prefixes:

- main hymnal: `d*.png`
- supplement: `b*.png`
- children: `n*.png`

Children hymns are currently simple: image index is `number + 4`.

Main and supplement mappings were ported from the APK's song selection/image mapping logic. The supplement comments mention `new.apk com.example.song.maintouch`; preserve these offsets unless re-checking the APK mapping carefully.

If adding or moving image files, make sure they are included as app resources in `ReadFreshTest.xcodeproj/project.pbxproj`, otherwise `Bundle.main.url(..., subdirectory: "HymnImages")` will return nil at runtime.

## Firebase / Reading Data Scripts

The `scripts/` folder contains Python utilities for scraping and Firebase updates.

Important files:

- `scripts/run.py`: scrapes weekly reading content and writes to Firebase
- `scripts/firebase.py`: small Firestore wrapper
- `scripts/delete_old_firebase_data.py`: cleanup tool, dry-run by default
- `scripts/constant.py`: source URLs grouped by training/week

The scripts may need dependencies such as pandas, BeautifulSoup, curl_cffi, and firebase-admin. Network may be restricted in the Codex environment, so do not assume these can run without approval.

## Common Commands

Build iOS simulator target:

```sh
xcodebuild -quiet -project iOS-App/ReadFreshTest/ReadFreshTest.xcodeproj -scheme ReadFreshTest -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Check Swift edits for whitespace issues:

```sh
git diff --check -- iOS-App/ReadFreshTest/ReadFreshTest/HymnView.swift iOS-App/ReadFreshTest/ReadFreshTest/HymnDB.swift
```

Inspect one hymn:

```sh
sqlite3 iOS-App/ReadFreshTest/ReadFreshTest/hymns.db \
  "select article, serial, lyric from hymnal where language='big5' and catalog=1 and number='1' order by article, cast(serial as int);"
```

Inspect chorus rows:

```sh
sqlite3 iOS-App/ReadFreshTest/ReadFreshTest/hymns.db \
  "select article, serial, begin, end, chorus from hchorus where language='big5' and catalog=1 and number='1' order by article, serial;"
```

## Current Worktree Notes

At the time this file was created, the hymn feature changes were intentional and may still appear as uncommitted changes:

- `ContentView.swift` passes hymn tab activity to `HymnView`
- `HymnView.swift` contains the new hymn UI, search, detail, image zoom, reset behavior
- `HymnDB.swift` contains directory/search/chorus support
- `HymnImageProvider.swift` and `HymnImages/` were added for image mode
- `project.pbxproj` was updated to include DB/images/resources

Do not revert these changes unless the user explicitly asks.

## Coding Guidelines For This Repo

- Prefer `rg` for searches.
- Use `apply_patch` for manual file edits.
- Do not revert unrelated dirty files; assume they are user or prior-agent work.
- Keep SwiftUI edits consistent with the existing small-view style in this app.
- For hymn DB behavior, verify with sqlite before guessing. In particular, never treat `article` as the verse number.
- For dark mode, avoid hard-coded black text unless explicitly requested. Use `.primary`.
- For hymn text detail, preserve settings-driven font size and line spacing.
- For image mode, preserve default image display and pinch zoom behavior.
- After code edits, run the xcodebuild command above when feasible and report whether it passed.
