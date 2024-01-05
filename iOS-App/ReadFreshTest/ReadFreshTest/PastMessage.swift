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
    @Query(filter: #Predicate<ReadData_v2> { read in
        if read.ended_day < currentDate {
            return true
        } else {
            return false
        }
    },
           sort: \.created_day,
           order: .reverse
    ) var reads: [ReadData_v2]
    
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    
    @AppStorage(UserDefaultsDataKeys.lineSpacingSize) private var lineSpacingSize: Double = 8.0
    
    @AppStorage(UserDefaultsDataKeys.showTitle) private var showTitle = true
    
    
    
    var body: some View {
        NavigationStack {
            if reads.isEmpty {
                ContentUnavailableView(
                    "沒有資料",
                    systemImage: "swiftdata",
                    description: Text("請開啟網路後重啟App")
                )
            } else {
                List(reads) { read in
                    NavigationLink {
                        if showTitle {
                            TitleIView(read: read)
                                .padding(.horizontal)
                        }
                        dayMessageView(read: read)
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
                    } label: {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(read.section_number)
                                Spacer()
                                Text(read.training_year)
                            }
                            .padding(.vertical)
                            Text(read.section_name)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.black)
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
