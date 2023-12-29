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
        
        HStack {
            Text("\(read.training_topic)")
                .font(.title)
            Text("\(read.training_year)")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical)
        Text("\(read.section_name)")
            .font(.title3.bold())
        
    }
}

//#Preview {
//    TitleIView()
//}
