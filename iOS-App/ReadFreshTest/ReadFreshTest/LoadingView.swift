//
//  LoadingView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/25.
//

import SwiftUI

struct LoadingView: View {
    @State private var didStartAnimation = false
    var body: some View {
        VStack {
            Image(systemName: "ellipsis")
                .resizable()
                .scaledToFit()
                .symbolEffect(.pulse.byLayer)
                .symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing)
                .symbolEffect(.bounce.byLayer, options: .repeating.speed(0.1), value: didStartAnimation)
                .onAppear { didStartAnimation = true }
                .foregroundStyle(.indigo)
            
        }
        .padding()
    }
}



#Preview {
    LoadingView()
}
