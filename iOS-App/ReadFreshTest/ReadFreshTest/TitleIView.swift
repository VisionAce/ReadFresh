//
//  TitleIView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/27.
//

import SwiftUI

struct TitleIView: View {
    let read : ReadData_v2
    var body: some View {
        Group {
            Text("\(read.training_topic)")
//                .font(.title3.bold())
            
            Text("\(read.section_name)")
//                .font(.headline.bold())
            
            HStack {
                Spacer()
                Text("\(read.training_year)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

//#Preview {
//    TitleIView()
//}
