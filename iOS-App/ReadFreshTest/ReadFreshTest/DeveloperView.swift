//
//  DeveloperView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2024/1/4.
//

import SwiftUI

struct DeveloperView: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage(UserDefaultsDataKeys.localVersion) private var localVersion = 0
    @Binding var showdata: Bool
    let reads: [ReadData_v2]
    
    var body: some View {
        Form {
            Section {
                Text("local版本：\(localVersion)")
                Text("模型資料數\(reads.count)")
            }
            
            Section {
                Button("刪除模型與重置版本") {
                    do {
                        try modelContext.delete(model: ReadData_v2.self)
                        
                    } catch {
                        print("Failed to delete Read data.")
                    }
                    
                    localVersion = 0
                }
                
                Button("Read") {
                    showdata.toggle()
                }
                if showdata {
                    if reads.isEmpty {
                        Text("No Data")
                    } else {
                        let nowDate = Date.now
                        
                        Text("\(reads[0].section_name)\n")
                        Text("\(reads[0].outline[0].context[7])\n")
                        Text("\(reads[0].day_messages[0].data[0].context[0])")
                        Text("現在時間： \(nowDate.formatted(date: .complete, time: .complete))")
                    }
                    
                }
            }
        }
    }
}
