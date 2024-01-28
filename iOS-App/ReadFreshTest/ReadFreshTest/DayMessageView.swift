//
//  dayMessageView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/27.
//

import SwiftUI

struct DayMessageView: View {
    let read: ReadData_v2
    let dayPicker: String
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    @AppStorage(UserDefaultsDataKeys.lineSpacingSize) private var lineSpacingSize: Double = 8.0
    
    @GestureState private var magnifyBy = 1.0
    @State private var lastGestureState = 0.0
    @State private var colorData = ColorData()

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
    
    init(read: ReadData_v2, dayPicker: String) {
        self.read = read
        self.dayPicker = dayPicker
     //This changes the "thumb" that selects between items
        UISegmentedControl.appearance().selectedSegmentTintColor = colorData.uiColor
      
     //This changes the color for the whole "bar" background
        UISegmentedControl.appearance().backgroundColor = .lightText

      
     //This will change the font size
     UISegmentedControl.appearance().setTitleTextAttributes([.font : UIFont.preferredFont(forTextStyle: .headline)], for: .highlighted)
        UISegmentedControl.appearance().setTitleTextAttributes([.font : UIFont.preferredFont(forTextStyle: .subheadline)], for: .normal)
      
     //these lines change the text color for various states
     UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor : UIColor.cyan], for: .highlighted)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor : UIColor.white], for: .selected)
   }
    
    var body: some View {
                VStack(alignment: .leading) {
                    if dayPicker == "綱要" {
                        ForEach(read.outline, id: \.self) { data in
                            if let firstIndex = data.context.firstIndex(where: { $0.contains("詩歌：") }) {
                                ForEach(firstIndex..<data.context.count, id: \.self) { index in
                                    Text("\(data.context[index])\n")
                                }
                            }
                        }
                    } else {
                        ForEach(read.day_messages, id: \.self) { day_message in
                            if dayPicker == day_message.day  {
                                ForEach(day_message.data, id: \.self) { page in
                                    if let firstIndex = page.context.firstIndex(where: { $0.contains("晨興餧養") }) {
                                        ForEach(firstIndex..<page.context.count, id: \.self) { index in
                                            Text("\(page.context[index])\n")
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

//#Preview {
//    DayMessageView(reads: [])
//}
