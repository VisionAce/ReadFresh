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
    static let updatedTime = Calendar.current.date(byAdding: .hour, value: 12, to: currentDate)!
    @Query(filter: #Predicate<ReadData_v2> { read in
        if read.ended_day > updatedTime && read.started_day < updatedTime {
            return true
        } else {
            return false
        }
    }
    ) var reads: [ReadData_v2]
    
    var uniqueReads: [ReadData_v2] {
        var result = [ReadData_v2]()
        for read in reads {
            if result.isEmpty {
                result.append(read)
            } else {
                if read.section_number == result.last!.section_number || read.started_day == result.last!.started_day || read.ended_day == result.last!.ended_day {
                    if read.created_day > result.last!.created_day {
                        result.removeLast()
                        result.append(read)
                    }
                    // not need to append
                    
                } else {
                    result.append(read)
                }
            }
        }
        return result
    }
    
    var weeks: [String] {
        var res = [String]()
        for read in uniqueReads {
            res.append(read.section_number)
        }
        return res
    }
    
    @State private var weekPickerIndex = 0
    @AppStorage(UserDefaultsDataKeys.showTitle) private var showTitle = true
    
    var body: some View {
        NavigationStack {
            VStack {
                if uniqueReads.isEmpty {
                    //                    Text("沒有資料")
                } else {
                    if showTitle {
                        TitleIView(read: uniqueReads[weekPickerIndex])
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
                
                if uniqueReads.isEmpty {
                    ContentUnavailableView(
                        "沒有資料",
                        systemImage: "swiftdata",
                        description: Text("請開啟網路後重啟App，或等待資料更新，謝謝～")
                    )
                } else {
                    dayMessageView(read: uniqueReads[weekPickerIndex])
                }
                
            }
            .padding(.horizontal)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle(isOn: $showTitle) {
                        Text(showTitle ? "關閉標題" : "顯示標題")
                    }
                    .padding(.horizontal)
                    
                }
            }
            
            Spacer()

        }
    }
}


#Preview {
    MessageView()
}
