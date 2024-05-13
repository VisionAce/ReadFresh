//
//  PastMessage.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2024/1/4.
//

import SwiftUI
import SwiftData

enum PastMessageSorted {
    case none, trainName, year, trainNameAndyear
}

struct TopicRead: Hashable {
    let topicName: String
    let data: [ReadData_v2]
    var id: String { topicName }
}

struct PastMessage: View {
    
    @State private var trainNamePicker = "預設"
    @State private var yearPicker = "預設"
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    @AppStorage(UserDefaultsDataKeys.activateDarkMode) private var activateDarkMode = false
    @State private var pastMessageSorted: PastMessageSorted = .none
    @State private var colorData = ColorData()
    
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
            if read.section_number.contains(" ") {
                // not need to append
            } else {
                if result.isEmpty {
                    result.append(read)
                } else {
                    if read.section_number == result.last!.section_number {
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
        }
        return result
    }
    
    var topics: [String] {
        var res = [String]()
        res.append("預設")
        for read in uniqueReads {
            if res.last! != read.training_name {
                res.append(read.training_name)
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
            if read.training_name == trainNamePicker {
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
            if read.training_name == trainNamePicker && read.training_year == yearPicker {
                result.append(read)
            }
        }
        return result
    }
    
    var sortRead: [ReadData_v2] {
        switch pastMessageSorted {
        case .none:
            return uniqueReads
        case .trainName:
            return topicsReads
        case .year:
            return yearsReads
        case .trainNameAndyear:
            return topicsAndYearsReads
        }
    }
    
    var topicList: [String] {
        var result = [String]()
        for read in sortRead {
            if result.isEmpty {
                result.append(read.training_topic)
            } else {
                if result.last! != read.training_topic {
                    result.append(read.training_topic)
                } else {
                    // no need to append
                }
            }
        }
        return result
    }
    
    var filteredRead: [TopicRead] {
        var result = [TopicRead]()
        for topic in topicList {
            var data = [ReadData_v2]()
            for read in sortRead {
                if read.training_topic == topic {
                    data.append(read)
                }
            }
            let save = TopicRead(topicName: topic, data: data)
            result.append(save)
            data.removeAll()
        }
        return result
    }
    
    var body: some View {
        NavigationStack {
            if uniqueReads.isEmpty {
                List {
                    ContentUnavailableView(
                        "沒有資料",
                        systemImage: "swiftdata",
                        description: Text("請開啟網路後重啟App，或等待資料更新，謝謝～\n\n下拉可刷新頁面")
                    )
                }
            } else {
                
                Grid {
                    GridRow {
                        Text("類別")
                        Text("年份")
                    }
                    .font(.title2.bold())
                    GridRow {
                        Picker("訓練類別", selection: $trainNamePicker) {
                            ForEach(topics, id: \.self) {
                                Text($0)
                            }
                        }
                        Picker("訓練年份", selection: $yearPicker) {
                            ForEach(years, id: \.self) {
                                Text($0)
                            }
                        }
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .onChange(of: trainNamePicker) {
                    if yearPicker != "預設" && trainNamePicker == "預設" {
                        pastMessageSorted = .year
                        print("year")
                    }
                    if yearPicker != "預設" && trainNamePicker != "預設" {
                        pastMessageSorted = .trainNameAndyear
                        print("trainNameAndyear")
                    }
                    if yearPicker == "預設" && trainNamePicker != "預設" {
                        pastMessageSorted = .trainName
                        print("trainName")
                    }
                    if yearPicker == "預設" && trainNamePicker == "預設" {
                        pastMessageSorted = .none
                        print("none")
                    }
                }
                .onChange(of: yearPicker) {
                    if yearPicker != "預設" && trainNamePicker == "預設" {
                        pastMessageSorted = .year
                        print("year")
                    }
                    if yearPicker != "預設" && trainNamePicker != "預設" {
                        pastMessageSorted = .trainNameAndyear
                        print("trainNameAndyear")
                    }
                    if yearPicker == "預設" && trainNamePicker != "預設" {
                        pastMessageSorted = .trainName
                        print("trainName")
                    }
                    if yearPicker == "預設" && trainNamePicker == "預設" {
                        pastMessageSorted = .none
                        print("none")
                    }
                }
                
                List(filteredRead, id: \.self) { item in
                    Section(header: Text("\(item.topicName)")
                        .bold()
                        .lineLimit(1)) {
                        ForEach(item.data) { read in
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
                                        Text(read.training_name)
                                            .font(.caption)
                                            .padding(3)
                                            .foregroundStyle(.windowBackground)
                                            .background(
                                                Capsule()
                                                    .foregroundStyle(colorData.themeColor.gradient)
                                            )
                                        Spacer()
                                        Text(read.training_year)
                                            .font(.caption)
                                            .padding(3)
                                            .foregroundStyle(.windowBackground)
                                            .background(
                                                Capsule()
                                                    .foregroundStyle(colorData.themeColor.gradient)
                                            )
                                    }
                                    HStack {
                                        Text(read.section_number)
                                            .padding(.vertical)
                                        
                                        Text(read.section_name)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(5)
                            }
                            
                        }
                        
                    }
                        .headerProminence(.increased)
                }
                .scrollIndicators(.hidden)
//                .clipShape(RoundedRectangle(cornerRadius: 20))
//                .padding()
                .padding(.bottom, 65)
//                .background(activateDarkMode ? Color.black.gradient : colorData.themeColor.gradient)
                .listStyle(.plain)
//                .listStyle(GroupedListStyle())
                                
            }
        }
    }
}


//#Preview {
//
//    PastMessage()
//}
