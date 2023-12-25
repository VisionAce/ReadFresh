//
//  SettingView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/25.
//

import SwiftUI

struct SettingView: View {
    @AppStorage(UserDefaultsDataKeys.showTitle) private var showTitle = true
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    @AppStorage(UserDefaultsDataKeys.lineSpacingSize) private var lineSpacingSize: Double = 8.0
    
    var body: some View {
        Form {
            Section("基本設定") {
                
                
                HStack {
                    Image(systemName: "list.dash.header.rectangle")
                        .foregroundStyle(.indigo)
                    Toggle("是否顯示標題?", isOn: $showTitle)
                }
                .padding(.horizontal)
                HStack {
                    Image(systemName: "character.bubble.fill.zh")
                        .foregroundStyle(.indigo)
                    Text("字級 \(fontSize, specifier: "%.2f")")
                    Slider(value: $fontSize,
                           in: 18.0...50.0)
                }
                .padding(.horizontal)
                
                HStack {
                    Image(systemName: "line.horizontal.star.fill.line.horizontal")
                        .foregroundStyle(.indigo)
                    Text("行距：\(lineSpacingSize, specifier: "%.2f")")
                    Slider(value: $lineSpacingSize,
                           in: 8.0...20.0)
                }
                .padding(.horizontal)
            }
            
            Section("顯示") {
                Text("""
哥林多前書 10:23-24 RCUV

「凡事都可行」，但不都有益處。「凡事都可行」，但不都造就人。 無論甚麼人，不要求自己的益處，而要求別人的益處。
""")
                .font(.system(size: fontSize))
                .lineSpacing(lineSpacingSize)
                .padding(.horizontal)
                
            }
        }
        
    }
}

#Preview {
    SettingView()
}
