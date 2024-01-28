//
//  SettingView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/25.
//

import SwiftUI

struct SettingView: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    @AppStorage(UserDefaultsDataKeys.lineSpacingSize) private var lineSpacingSize: Double = 8.0
    
    @GestureState private var longPressTap = false
    @State private var isPressed = false
    @State private var showdata = false
    
    @State private var color: Color = Color.brown
    @State private var colorData = ColorData()
    
    let reads: [ReadData_v2]
    var body: some View {
        NavigationStack {
            
            Form {
                Section("顏色") {
                    ColorPicker("選擇您要的主題顏色", selection: $color)
                        .padding(.horizontal)
                        .onChange(of: color) {
                            colorData.saveColor(color: color)
                            color = colorData.loadColor()
                        }
                }
                
                Section("基本設定") {
                    HStack {
                        Image(systemName: "character.bubble.fill.zh")
                            .foregroundStyle(colorData.themeColor)
                        Text("字級 \(fontSize, specifier: "%.0f")")
                        Slider(value: $fontSize,
                               in: 18...50,
                               step: 1)
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "line.horizontal.star.fill.line.horizontal")
                            .foregroundStyle(colorData.themeColor)
                        Text("行距 \(lineSpacingSize, specifier: "%.0f")")
                        Slider(value: $lineSpacingSize,
                               in: 8...20,
                               step: 1)
                    }
                    .padding(.horizontal)
                }
                
                Section("顯示") {
                    Text("""
哥林多前書 10:23-24 RCUV

「凡事都可行」，但不都有益處。「凡事都可行」，但不都造就人。 無論甚麼人，不要求自己的益處，而要求別人的益處。
""")
                    .font(.system(size: fontSize))
                    .foregroundStyle(colorData.themeColor)
                    .lineSpacing(lineSpacingSize)
                    .padding(.horizontal)
                    .containerShape(Rectangle())
                    .gesture(
                        LongPressGesture(minimumDuration: 5.0)
                            .updating($longPressTap, body: {(currentState, state, transaction) in
                                state = currentState
                            })
                            .onEnded({ _ in
                                isPressed.toggle()
                            })
                    )
                    .sheet(isPresented: $isPressed) {
                        DeveloperView(modelContext: _modelContext, showdata: $showdata, reads: reads)
                    }
                }
        
            }
            .navigationTitle("設定")
            .onAppear {
                color = colorData.loadColor()
            }
            
        }
    }
}

//#Preview {
//    SettingView()
//}
