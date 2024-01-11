//
//  Tab.swift
//  CurvedCustomTabBar
//
//  Created by 褚宣德 on 2024/1/10.
//

import SwiftUI

/// App Tab's

enum Tab: String, CaseIterable {
    case thisWeek = "本週"
    case pastWeek = "已過"
    case setting = "設定"
    
    var systemImage: String {
        switch self {
        case .thisWeek:
            return "book.pages"
        case .pastWeek:
            return "book.fill"
        case .setting:
            return "gear"
 
        }
    }
    
    var index: Int {
        // return current tab index
        return Tab.allCases.firstIndex(of: self) ?? 0
    }
}
