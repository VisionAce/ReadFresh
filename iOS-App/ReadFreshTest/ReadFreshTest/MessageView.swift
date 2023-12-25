//
//  MessageView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/8.
//

import SwiftUI
import SwiftData

struct MessageView: View {
    @State private var dayPicker = "綱要"

    let reads : [ReadData_v2]
    
    let days:[String] = ["綱要", "週一", "週二", "週三", "週四", "週五", "週六"]
    
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    
    @AppStorage(UserDefaultsDataKeys.lineSpacingSize) private var lineSpacingSize: Double = 8.0
    
    @AppStorage(UserDefaultsDataKeys.showTitle) private var showTitle = true
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Day", selection: $dayPicker) {
                    
                    ForEach(days, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.palette)
                .padding(.horizontal)
                Spacer()
                ScrollView(.vertical) {
                    
                    VStack(alignment: .leading) {
                        if reads.isEmpty {
                            ContentUnavailableView(
                                "沒有資料",
                                systemImage: "swiftdata",
                                description: Text("請開啟網路後重啟App")
                            )
                        } else {
                            
                            if dayPicker == "綱要" {
                                ForEach(reads) { read in
                                    ForEach(read.outline, id: \.self) { data in
                                        ForEach(data.context, id: \.self) { context in
                                            Text("\(context)\n")
                                        }
                                    }
                                }
                            } else if dayPicker == "週一" {
                                ForEach(reads) { read in
                                    ForEach(read.day_messages[0].data[0].context, id: \.self) { context in
                                        Text("\(context)\n")
                                    }
                                }
                            } else if dayPicker == "週二" {
                                ForEach(reads) { read in
                                    ForEach(read.day_messages[1].data[0].context, id: \.self) { context in
                                        Text("\(context)\n")
                                    }
                                }
                            } else if dayPicker == "週三" {
                                ForEach(reads) { read in
                                    ForEach(read.day_messages[2].data[0].context, id: \.self) { context in
                                        Text("\(context)\n")
                                    }
                                }
                            } else if dayPicker == "週四" {
                                ForEach(reads) { read in
                                    ForEach(read.day_messages[3].data[0].context, id: \.self) { context in
                                        Text("\(context)\n")
                                    }
                                }
                                
                            } else if dayPicker == "週五" {
                                ForEach(reads) { read in
                                    ForEach(read.day_messages[4].data[0].context, id: \.self) { context in
                                        Text("\(context)\n")
                                    }
                                }
                                
                            } else if dayPicker == "週六" {
                                ForEach(reads) { read in
                                    ForEach(read.day_messages[5].data[0].context, id: \.self) { context in
                                        Text("\(context)\n")
                                    }
                                }
                                
                            }
                            
                        }
                        
                    }
                }
                .lineSpacing(lineSpacingSize)
                
                
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .font(.system(size: fontSize))
        .contentShape(Rectangle())
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    // 根據手勢缩放的比例調整字體大小
                    let newFontSize = 18.0 * value
                    // 將字體大小限制在18.0到50.0之間
                    if (18.0...50.0).contains(newFontSize) {
                        self.fontSize = newFontSize
                    }
                }
        )
    }
}






#Preview {
    
    MessageView(reads: [])
}
