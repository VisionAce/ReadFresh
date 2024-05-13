//
//  AppStoreData.swift
//  VersionUpdateAppStore
//
//  Created by 褚宣德 on 2024/4/28.
//

import SwiftUI

// MARK: - Welcome
struct AppStoreData: Codable {
    let resultCount: Int
    let results: [AppStoreDataResult]
}

// MARK: - Result
struct AppStoreDataResult: Codable {
    let version: String
}
