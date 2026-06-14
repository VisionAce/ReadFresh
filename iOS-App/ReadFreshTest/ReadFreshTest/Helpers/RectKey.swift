//
//  RectKey.swift
//  TelegramDarkModeAnimation
//
//  Created by 褚宣德 on 2024/1/11.
//

import SwiftUI

struct RectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
