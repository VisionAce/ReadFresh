//
//  dayMessageView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/27.
//

import SwiftUI

struct dayMessageView: View {
    let read: ReadData_v2
    @State private var dayPicker = "綱要"
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    
    @AppStorage(UserDefaultsDataKeys.lineSpacingSize) private var lineSpacingSize: Double = 8.0

    var days: [String] {
        var res = ["綱要"]
//        for read in reads {
            for title in read.day_messages {
                res.append(title.day)
//            }
        }
        return res
    }
    
    var body: some View {
        VStack {
            
            Picker("Day", selection: $dayPicker) {
                
                ForEach(days, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(.palette)
            .padding([.horizontal, .bottom])
            
            ScrollView(.vertical) {
                VStack(alignment: .leading) {
                    if dayPicker == "綱要" {
//                        ForEach(reads) { read in
                            ForEach(read.outline, id: \.self) { data in
                                ForEach(data.context, id: \.self) { context in
                                    Text("\(context)\n")
                                }
                            }
//                        }
                    } else {
//                        ForEach(reads) { read in
                            ForEach(read.day_messages, id: \.self) { day_message in
                                if dayPicker == day_message.day  {
                                    ForEach(day_message.data, id: \.self) { page in
                                        ForEach(page.context, id: \.self) { context in
                                            Text("\(context)\n")
                                        }
                                    }
                                }
                                
                            }
//                        }
                        
                    }
                }
            }
            .lineSpacing(lineSpacingSize)
            .font(.system(size: fontSize))
            .contentShape(Rectangle())
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        // 根據手勢缩放的比例調整字體大小
                        let newFontSize = 18.0 * value
                        // 將字體大小限制在18.0到50.0之間
                        let rang = 18...50
                        if (rang).contains(Int(newFontSize)) {
                            self.fontSize = newFontSize
                        }
                    }
            )
        }
        
    }
}

//#Preview {
//    dayMessageView(reads: [])
//}
