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
        var tmp_result = [ReadData_v2]()
        var read_exist = false
        for read in reads {
            if !(read.section_number.contains("第") || read.section_number.contains("週")) {
                continue
            }
            if read.section_number.contains(" ") {
                // not need to append
                continue
            }
            if result.isEmpty {
                tmp_result.append(read)
            } else {
                for r in result {
                   if read.section_number == r.section_number && read.training_topic == r.training_topic  {
                       read_exist = true
                        if read.created_day > r.created_day {
                            tmp_result.removeAll(where: { $0.section_number == read.section_number && $0.training_topic == read.training_topic })
                            
                            tmp_result.append(read)
                        }
                    }
                }
                if read_exist == false {
                    tmp_result.append(read)
                }
            }
            read_exist = false
            result = tmp_result
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
    
    var body: some View {
        NavigationStack {
            VStack {
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
                    List {
                        ContentUnavailableView(
                            "沒有資料",
                            systemImage: "swiftdata",
                            description: Text("請開啟網路後重啟App，或等待資料更新，謝謝～\n\n下拉可刷新頁面")
                        )
                    }
                } else {
                    GeometryReader {
                        let size = $0.size
                        let safeArea = $0.safeAreaInsets
                        if uniqueReads.isEmpty {
                            // No Data
                        } else {
                            ArticleView(size: size, safeArea: safeArea, read: uniqueReads[weekPickerIndex])
                                .ignoresSafeArea(.all, edges: .top)
                        }
                    }
                }
            }
            Spacer()
        }
    }
}


#Preview {
    MessageView()
}
