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
                .foregroundStyle(.primary)
                .font(.subheadline)
            
            Text("\(read.section_name)")
                .foregroundStyle(.primary)
                .font(.headline)
                .padding(.bottom)
            
        }
    }
}

//#Preview {
//    TitleIView()
//}
