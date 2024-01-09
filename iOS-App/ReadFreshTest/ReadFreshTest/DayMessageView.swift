//
//  dayMessageView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/27.
//

import SwiftUI

struct DayMessageView: View {
    let read: ReadData_v2
    @State private var dayPicker = "綱要"
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    @AppStorage(UserDefaultsDataKeys.lineSpacingSize) private var lineSpacingSize: Double = 8.0
    

    @GestureState private var magnifyBy = 1.0
    @State private var lastGestureState = 0.0
    
    var days: [String] {
        var res = ["綱要"]
        for title in read.day_messages {
            res.append(title.day)
        }
        return res
    }
    
    var magnification: some Gesture {
        MagnifyGesture()
            .updating($magnifyBy) { value, gestureState, transaction in
                
                gestureState = value.magnification
                //print("\(gestureState)")
            }
            .onChanged { value in
                fontSize += min(0.5,max(-0.5,(value.magnification - lastGestureState))) * 10
                //print("Size: \(value.magnification - lastGestureState)")
                fontSize = min(50,max(18,fontSize))
                //print("fontSize: \(fontSize)")
                lastGestureState = value.magnification
                //print("lastGestureState: \(lastGestureState)")
            }
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
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading) {
                    if dayPicker == "綱要" {
                        ForEach(read.outline, id: \.self) { data in
                            ForEach(data.context, id: \.self) { context in
                                Text("\(context)\n")
                            }
                        }
                    } else {
                        ForEach(read.day_messages, id: \.self) { day_message in
                            if dayPicker == day_message.day  {
                                ForEach(day_message.data, id: \.self) { page in
                                    ForEach(page.context, id: \.self) { context in
                                        Text("\(context)\n")
                                    }
                                }
                            }
                            
                        }
                    }
                }
            }
            .lineSpacing(lineSpacingSize)
            .font(.system(size: fontSize))
            .contentShape(Rectangle())
            .gesture(magnification)
        }
    }
}

//#Preview {
//    DayMessageView(reads: [])
//}
