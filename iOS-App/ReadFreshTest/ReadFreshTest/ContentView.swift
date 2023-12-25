//
//  ContentView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/4.
//

import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ContentView: View {
    var body: some View {
        TabView {
            HomeVIew()
                .tabItem {
                    Label("本週", systemImage: "book.pages")
                        .foregroundStyle(.indigo)
                }
            
            SettingView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                        .foregroundStyle(.indigo)
                }
        }
  
    }
}
    
 

#Preview {
    ContentView()
}
