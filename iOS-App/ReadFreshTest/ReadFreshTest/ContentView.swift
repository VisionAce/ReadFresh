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
    
    
    @FirestoreQuery(collectionPath: "stg-data") var message: [Stgdata_v1]
    @Environment(\.modelContext) var modelContext
    @State private var week = "第八週"
    let weeks = ["第八週", "第九週"]
    @AppStorage("version") private var localVersion = ""
  
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("week", selection: $week) {
                    ForEach(weeks, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.segmented)
                
                
                ForEach(message, id: \.created_day) { message in
                    HStack {
                        Text(message.section_number)
                        Text(message.id!)
                    }
                }
                
               Text("本地版本\(localVersion)")
                
                Spacer()
                
            }
            .onAppear {
                if localVersion.isEmpty {
                    addVersion()
                }
                DataManager().test()
                
            }
            
            
            .navigationTitle("晨興聖言")
        }
        
        
        
    }
    
    func addVersion() {
        
        let db = Firestore.firestore()
        db.collection("stg-metadata").getDocuments { snapshot, error in
            guard let snapshot else { return }
            
            let words = snapshot.documents.compactMap { snapshot in
                try? snapshot.data(as: StgMetadata.self)
            }
            localVersion = words.first!.version
            print(localVersion)
        }
    }
    
    func save() {
        
    }
    
//    func getSectionNumber() {
//       
//        
//        let db = Firestore.firestore()
//        db.collection("stg-data").getDocuments { snapshot, error in
//            guard let snapshot else { return }
//            
//            let words = snapshot.documents.compactMap { snapshot in
//                try? snapshot.data(as: Stgdata.self)
//            }
//            for word in words {
//                
//                let a = word.section_number
//                readSet.insert(a)
//                readArray.append(a)
//                
//            }
//            print(readSet)
//            
//        }
//        print(readArray)
//    
//    }
    
}
    



    

#Preview {
    ContentView()
}
