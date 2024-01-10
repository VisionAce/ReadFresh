//
//  PastMessage.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2024/1/4.
//

import SwiftUI
import SwiftData


struct PastMessage: View {
    
    static let currentDate = Date()
    static let updatedTime = Calendar.current.date(byAdding: .hour, value: 12, to: currentDate)!
    @Query(filter: #Predicate<ReadData_v2> { read in
        if read.ended_day < updatedTime {
            return true
        } else {
            return false
        }
    },
           sort: \.created_day,
           order: .reverse
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
    
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    
    var body: some View {
        NavigationStack {
            if uniqueReads.isEmpty {
                ContentUnavailableView(
                    "沒有資料",
                    systemImage: "swiftdata",
                    description: Text("請開啟網路後重啟App，或等待資料更新，謝謝～")
                )
            } else {
                List(uniqueReads) { read in
                    NavigationLink {
                        GeometryReader {
                            let size = $0.size
                            let safeArea = $0.safeAreaInsets
                            
                            ArticleView(size: size, safeArea: safeArea, read: read)
                                .ignoresSafeArea(.all, edges: .top)
                        }
                        
                    } label: {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(read.section_number)
                                Spacer()
                                Text(read.training_year)
                            }
                            .font(.headline)
                            .padding(.vertical)
                            Text(read.section_name)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
                .background(.indigo.opacity(0.3))
                .listStyle(.plain)
            }
        }
    }
}


//#Preview {
//
//    PastMessage()
//}
