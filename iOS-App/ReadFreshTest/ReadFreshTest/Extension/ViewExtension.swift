//
//  ViewExtension.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2024/1/10.
//

import SwiftUI

extension View {
  func navigationBarBackground(_ background: Color = .orange) -> some View {
    return self
      .modifier(ColoredNavigationBar(background: background))
  }
}

struct ColoredNavigationBar: ViewModifier {
  var background: Color
  
  func body(content: Content) -> some View {
    content
      .toolbarBackground(
        background,
        for: .navigationBar
      )
      .toolbarBackground(.visible, for: .navigationBar)
  }
}
