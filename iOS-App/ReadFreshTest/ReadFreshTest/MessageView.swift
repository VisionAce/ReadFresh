//
//  MessageView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/8.
//

import SwiftUI
import SwiftData



struct MessageView: View {
    @State private var dayPicker = "綱要"
    static let currentDate = Date()
    @Query(filter: #Predicate<ReadData_v2> { read in
        if read.ended_day > currentDate && read.started_day < currentDate {
            return true
        } else {
            return false
        }
    }
    ) var reads: [ReadData_v2]
    
    let days:[String] = ["綱要", "週一", "週二", "週三", "週四", "週五", "週六"]
    
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Day", selection: $dayPicker) {
                    
                    ForEach(days, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.palette)
                .padding(.horizontal)
                Spacer()
                ScrollView(.vertical) {
                    
                    VStack(alignment: .leading) {
                    if dayPicker == "綱要" {
                        ForEach(reads) { read in
                            ForEach(read.outline, id: \.self) { data in
                                ForEach(data.context, id: \.self) { context in
                                    Text("\(context)\n")
                                }
                            }
                        }
                    } else if dayPicker == "週一" {
                        ForEach(reads) { read in
                            ForEach(read.day_messages[0].data[0].context, id: \.self) { context in
                                Text("\(context)\n")
                            }
                        }
                    } else if dayPicker == "週二" {
                        ForEach(reads) { read in
                            ForEach(read.day_messages[1].data[0].context, id: \.self) { context in
                                Text("\(context)\n")
                            }
                        }
                    } else if dayPicker == "週三" {
                        ForEach(reads) { read in
                            ForEach(read.day_messages[2].data[0].context, id: \.self) { context in
                                Text("\(context)\n")
                            }
                        }
                    } else if dayPicker == "週四" {
                        ForEach(reads) { read in
                            ForEach(read.day_messages[3].data[0].context, id: \.self) { context in
                                Text("\(context)\n")
                            }
                        }
                        
                    } else if dayPicker == "週五" {
                        ForEach(reads) { read in
                            ForEach(read.day_messages[4].data[0].context, id: \.self) { context in
                                Text("\(context)\n")
                            }
                        }
                        
                    } else if dayPicker == "週六" {
                        ForEach(reads) { read in
                            ForEach(read.day_messages[5].data[0].context, id: \.self) { context in
                                Text("\(context)\n")
                            }
                        }
                        
                    }
                    
                }
                }
                .lineSpacing(6)
                
                
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("\(title)")
        .navigationBarTitleDisplayMode(.inline)
        
    }
    
    var title: String {
        return reads.first?.section_number ?? ""
    }
    
}






#Preview {
    MessageView()
}
