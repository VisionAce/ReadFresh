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
    @Environment(\.modelContext) var modelContext
    @Query var reads: [ReadData_v2]
    @State private var remoteVersion = -1
    @State private var checkRemoteVersionTaskCompleted = false
    
    @State private var showingloadingView = true
    @GestureState private var longPressTap = false
    @State private var isPressed = false
    
    @AppStorage(UserDefaultsDataKeys.localVersion) private var localVersion = 0
    @AppStorage(UserDefaultsDataKeys.showTitle) private var showTitle = true
    
    
    var body: some View {
        Group {
            if showingloadingView {
                
                Group {
                    Text("Loading . . .")
                    ProgressView()
                }
                .padding()
                .font(.largeTitle)
                
            } else {
                
                TabView {
                    MessageView()
                        .tabItem {
                            Label("本週", systemImage: "book.pages")
                                .foregroundStyle(.indigo)
                        }
                    
                    PastMessage()
                        .tabItem {
                            Label("已過", systemImage: "book.fill")
                                .foregroundStyle(.indigo)
                        }
                    
                    SettingView(reads: reads)
                        .tabItem {
                            Label("設定", systemImage: "gear")
                                .foregroundStyle(.indigo)
                        }   
                }
            }
        }
        .onAppear {
            checkRemoteVersionTask { }
        }
        .onChange(of: remoteVersion) {
            updateVersion(version: remoteVersion)
            print("~~~~~~~~~!!!!~~~~~~~~~~~~\n\(remoteVersion)")
        }
        .onChange(of: checkRemoteVersionTaskCompleted) {
            if checkRemoteVersionTaskCompleted {
                loadDataTask()
            }
        }
        .onChange(of: showingloadingView) {
            print("showingloadingView: \(showingloadingView)")
        }
        
    }
    
    func saveDataSwiftWithVersion(DBcollection: String, DBdocument: String) {
        let dataManager = DataManager()
        
        dataManager.db.collection(DBcollection).document(DBdocument).getDocument { document, error in
            
            guard let document,
                  document.exists,
                  let words = try? document.data(as: Stgdata_v1.self) else { return }
            
            
            let stgdata = ReadData_v2(
                id: words.id!,
                created_day: words.created_day,
                ended_day: words.ended_day,
                section_name: words.section_name,
                section_number: words.section_number,
                started_day: words.started_day,
                training_name: words.training_name,
                training_topic: words.training_topic,
                training_year: words.training_year,
                type: words.type
                
            )
            stgdata.outline = words.outline
            stgdata.day_messages = words.day_messages
            
            modelContext.insert(stgdata)
        }
    }
    
    func updateVersion(version: Int) {
        remoteVersion = version
    }
    
    func checkRemoteVersionTask(completion: @escaping () -> Void) {
        // Execute the checkRemoteVersionTask
        print("Local version:\(localVersion)")
        let dataManager = DataManager()
        
        // Get remote version
        dataManager.db.collection(StagingKeys.stgMetadata).document(StagingKeys.metadata).getDocument { document, error in
            guard let document,
                  document.exists,
                  let remoteMetadata = try? document.data(as: StgMetadata.self) else { return }
            
            updateVersion(version: Int(remoteMetadata.version)!)
            
            print("~~~~~~~~~~~~\nRemote version: \(remoteVersion)")
            
            checkRemoteVersionTaskCompleted = true
        }
        
        // After executing checkRemoteVersionTask, invoke the completion
        completion()
        
    }
    
    func loadDataTask() {
        // Compare the local version with the version on Firebase.
        let collection = StagingKeys.stgData
        print("AAAAAAAAA")
        print("Remote version: \(remoteVersion)")
        if localVersion < remoteVersion {
            
            print("FFFFFFFFFF")
            for version in (localVersion + 1)...remoteVersion {
                print("Version: \(version)")
                saveDataSwiftWithVersion(DBcollection: collection, DBdocument: "\(version)")
            }
            
            localVersion = remoteVersion
        }
        showingloadingView = false
    }
}



//#Preview {
//    ContentView()
//}
