//
//  PastMessage.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2024/1/4.
//

import SwiftUI
import SwiftData

enum PastMessageSorted {
    case none, topic, year, topicAndyear
}

struct PastMessage: View {
    
    @State private var topicPicker = "預設"
    @State private var yearPicker = "預設"
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    @State private var pastMessageSorted: PastMessageSorted = .none
    
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
    
    var topics: [String] {
        var res = [String]()
        res.append("預設")
        for read in uniqueReads {
            if res.last! != read.training_topic {
                res.append(read.training_topic)
            }
        }
        return res
    }
    
    var years: [String] {
        var res = [String]()
        res.append("預設")
        for read in uniqueReads {
            if res.last! != read.training_year {
                res.append(read.training_year)
            }
        }
        return res
    }
    
    var topicsReads: [ReadData_v2] {
        var result = [ReadData_v2]()
        for read in uniqueReads {
            if read.training_topic == topicPicker {
                result.append(read)
            }
        }
        return result
    }
    var yearsReads: [ReadData_v2] {
        var result = [ReadData_v2]()
        for read in uniqueReads {
            if read.training_year == yearPicker {
                result.append(read)
            }
        }
        return result
    }
    var topicsAndYearsReads: [ReadData_v2] {
        var result = [ReadData_v2]()
        for read in uniqueReads {
            if read.training_topic == topicPicker && read.training_year == yearPicker {
                result.append(read)
            }
        }
        return result
    }
    
    var sortRead: [ReadData_v2] {
        switch pastMessageSorted {
        case .none:
            return uniqueReads
        case .topic:
            return topicsReads
        case .year:
            return yearsReads
        case .topicAndyear:
            return topicsAndYearsReads
        }
    }
    
    var body: some View {
        NavigationStack {
            if uniqueReads.isEmpty {
                ContentUnavailableView(
                    "沒有資料",
                    systemImage: "swiftdata",
                    description: Text("請開啟網路後重啟App，或等待資料更新，謝謝～")
                )
            } else {
                
                HStack {
                    Picker("訓練主題", selection: $topicPicker) {
                        ForEach(topics, id: \.self) {
                            Text($0)
                        }
                    }
                    Spacer()
                    Picker("訓練年份", selection: $yearPicker) {
                        ForEach(years, id: \.self) {
                            Text($0)
                        }
                    }
                }
                .pickerStyle(.menu)
                .padding()
                
                List(sortRead) { read in
                    NavigationLink {
                        GeometryReader {
                            let size = $0.size
                            let safeArea = $0.safeAreaInsets
                            
                            ArticleView(size: size, safeArea: safeArea, read: read)
                                .ignoresSafeArea(.all, edges: .top)
                        }
                        
                    } label: {
                        VStack(alignment: .leading) {
                            Text(read.section_name)
                            HStack {
                                Text(read.section_number)
                                Spacer()
                                Text(read.training_year)
                                    .font(.caption)
                                    .clipShape(.capsule(style: .circular))
                                    .background(.orange.gradient)
                                    .padding()
                            }
                            
                            .padding(.vertical)
                        }
                        .font(.headline)
                        .padding()
                    }
                }
                .scrollIndicators(.hidden)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding()
                .padding(.bottom, 80)
                .background(.brown.gradient.opacity(0.3))
                .listStyle(.plain)
                .onChange(of: topicPicker) {
                    if yearPicker != "預設" && topicPicker == "預設" {
                        pastMessageSorted = .year
                        print("year")
                    }
                    if yearPicker != "預設" && topicPicker != "預設" {
                        pastMessageSorted = .topicAndyear
                        print("topicAndyear")
                    }
                    if yearPicker == "預設" && topicPicker != "預設" {
                        pastMessageSorted = .topic
                        print("topic")
                    }
                    if yearPicker == "預設" && topicPicker == "預設" {
                        pastMessageSorted = .none
                        print("none")
                    }
                }
                .onChange(of: yearPicker) {
                    if yearPicker != "預設" && topicPicker == "預設" {
                        pastMessageSorted = .year
                        print("year")
                    }
                    if yearPicker != "預設" && topicPicker != "預設" {
                        pastMessageSorted = .topicAndyear
                        print("topicAndyear")
                    }
                    if yearPicker == "預設" && topicPicker != "預設" {
                        pastMessageSorted = .topic
                        print("topic")
                    }
                    if yearPicker == "預設" && topicPicker == "預設" {
                        pastMessageSorted = .none
                        print("none")
                    }
                }
            }
        }
    }
}


//#Preview {
//
//    PastMessage()
//}
