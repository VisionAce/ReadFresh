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
            .padding(.horizontal)
            
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
        }
        
    }
}

//#Preview {
//    dayMessageView(reads: [])
//}
