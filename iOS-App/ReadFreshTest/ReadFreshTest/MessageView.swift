//
//  MessageView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/8.
//

import SwiftUI
import SwiftData

struct MessageView: View {
    
    static let currentDate = Date()
    @Query(filter: #Predicate<ReadData_v2> { read in
        if read.ended_day > currentDate && read.started_day < currentDate {
            return true
        } else {
            return false
        }
    }
    ) var reads: [ReadData_v2]
    
    @State private var weekPickerIndex = 0
    
    var weeks: [String] {
        var res = [String]()
        for read in reads {
            res.append(read.section_number)
        }
        return res
    }
    
    
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    
    @AppStorage(UserDefaultsDataKeys.lineSpacingSize) private var lineSpacingSize: Double = 8.0
    
    @AppStorage(UserDefaultsDataKeys.showTitle) private var showTitle = true
    
    var body: some View {
        NavigationStack {
            VStack {
                if reads.isEmpty {
                    //                    Text("沒有資料")
                } else {
                    if showTitle {
                        TitleIView(read: reads[weekPickerIndex])
                            .padding(.horizontal)
                    }
                }
                
                
                Picker("Week", selection: $weekPickerIndex) {
                    ForEach(0..<weeks.count, id: \.self) {
                        if weeks.isEmpty {
                            // No Data
                        } else {
                            Text(weeks[$0])
                        }
                    }
                }
                .pickerStyle(.palette)
                .padding(.horizontal)
                
                
                Spacer()
                
                if reads.isEmpty {
                    ContentUnavailableView(
                        "沒有資料",
                        systemImage: "swiftdata",
                        description: Text("請開啟網路後重啟App")
                    )
                } else {
                    dayMessageView(read: reads[weekPickerIndex])
                        .lineSpacing(lineSpacingSize)
                }
                
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}


#Preview {
    MessageView()
}
