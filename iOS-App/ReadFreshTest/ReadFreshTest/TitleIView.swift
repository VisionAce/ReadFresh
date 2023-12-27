//
//  TitleIView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/27.
//

import SwiftUI

struct TitleIView: View {
    let reads:[ReadData_v2]
    var body: some View {
        
        HStack {
            Text("\(reads.first?.training_topic ?? "")")
                .font(.title)
            Text("\(reads.first?.training_year ?? "")")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical)
        Text("\(reads.first?.section_name ?? "")")
            .font(.title3.bold())
        
    }
}

#Preview {
    TitleIView(reads: [])
}
