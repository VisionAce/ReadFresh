//
//  PostData.swift
//  FirebaseDataTest
//
//  Created by 褚宣德 on 2023/6/20.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift





struct StgMetadata: Codable, Identifiable {
    @DocumentID var id: String?
//    var id: String = UUID().uuidString
    let version: String

}

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    let born: Int
    let first: String
    let last: String
}



struct Stgdata_v1: Codable, Identifiable {
    @DocumentID var id: String?
    let created_day: Date
    let day_messages: [DayMessage]
    let db_version: String
    let ended_day: Date
    let outline: [ContextString]
    let section_name: String
    let section_number: String
    let started_day: Date
    let training_name: String
    let training_topic: String
    let training_year: String
    let type: String
}



struct DayMessage: Codable, Hashable {
   
    let data: [ContextString]
    let day: String
    let type: String
    let week: String
   
}


struct ContextString: Codable, Hashable, Identifiable {
    let page: String
    let context: [String]
    
    var id: String { page }
}


class DataManager {
    @Published var db = Firestore.firestore()

    
    // 提取括號之間的文本
    func extractTextBetweenBrackets(gpt: String) -> String.SubSequence {
        let befor = gpt.firstIndex(of: "]") ?? gpt.endIndex
        let after = gpt.firstIndex(of: "[") ?? gpt.endIndex
        let result = gpt[after...befor]
        return result
    }
    
    
    
    
    //拿取單字：讀取某個collection下全部的documents
    func fetchWords() {
        let db = Firestore.firestore()
        db.collection("stg-metadata").getDocuments { snapshot, error in
            guard let snapshot else { return }
            
            let words = snapshot.documents.compactMap { snapshot in
                try? snapshot.data(as: StgMetadata.self)
            }
            print(words)
        }
        
    }
    
    //持續偵測資料是否有更新
    
    func checkWordsChange() {
        
        let db = Firestore.firestore()
        db.collection("stg-metadata").addSnapshotListener { snapshot, error in
            guard let snapshot else { return }
            snapshot.documentChanges.forEach { documentChange in
                guard let word = try? documentChange.document.data(as: StgMetadata.self) else { return }
                switch documentChange.type {
                case .added:
                    print("added" , word)
                case .modified:
                    print("modified", word)
                case .removed:
                    print("removed", word)
                    
                }
            }
            
        }
    }
    
    
    func test() {
        let db = Firestore.firestore()
        db.collection("stg-data").document("17").getDocument { document, error in
            
            guard let document,
                  document.exists,
                  let song = try? document.data(as: Stgdata_v1.self) else { return }
            print(song)
        }
    }
    
        
    
}
