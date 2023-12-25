//
//  HomeVIew.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/8.
//

import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseFirestoreSwift



struct HomeVIew: View {
    @Environment(\.modelContext) var modelContext
    static let currentDate = Date()
    @Query(filter: #Predicate<ReadData_v2> { read in
        if read.ended_day > currentDate && read.started_day < currentDate {
            return true
        } else {
            return false
        }
    }
    ) var reads: [ReadData_v2]
    @State private var showdata = false
    @State private var remoteVersion = -1
    @State private var checkRemoteVersionTaskCompleted = false
    @State private var showingloadingView = true
    @GestureState private var longPressTap = false
    @State private var isPressed = false
    
    @AppStorage(UserDefaultsDataKeys.localVersion) private var localVersion = 0
    @AppStorage(UserDefaultsDataKeys.showTitle) private var showTitle = true
    
    var body: some View {
        NavigationStack {
            if showingloadingView {
                
                Group {
                    Text("Loading . . .")
                    ProgressView()
                }
                .padding()
                .font(.largeTitle)
                
            } else {
                
                if reads.isEmpty {
                    ContentUnavailableView(
                        "沒有資料",
                        systemImage: "swiftdata",
                        description: Text("請開啟網路後重啟App")
                    )
                } else {
                    VStack {
                        Group {
                            if showTitle {
                                HStack {
                                    Text("\(reads[0].training_topic)")
                                        .font(.title)
                                    Text("\(reads[0].training_year)")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical)
                                Text("\(reads[0].section_name)")
                                    .font(.title3.bold())
                            }
                        }
                        .padding(.horizontal)
                        .gesture(
                            LongPressGesture(minimumDuration: 10.0)
                                .updating($longPressTap, body: {(currentState, state, transaction) in
                                    state = currentState
                                })
                                .onEnded({ _ in
                                    isPressed.toggle()
                                })
                        )
                    }
                }
                
                MessageView(reads: reads)
                
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Toggle(isOn: $showTitle) {
                                Text(showTitle ? "關閉標題" : "顯示標題")
                            }
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
        
        .sheet(isPresented: $isPressed) {
            Text("local版本：\(localVersion)")
            Text("Firebase版本：\(remoteVersion)")
            Text("模型資料數\(reads.count)")
            Button("Delete") {
                do {
                    try modelContext.delete(model: ReadData_v2.self)
                    
                } catch {
                    print("Failed to delete Read data.")
                }
                
                localVersion = 0
                remoteVersion = -1
            }
            
            Button("Read") {
                showdata.toggle()
            }
            if showdata {
                if reads.isEmpty {
                    Text("No Data")
                } else {
                    
                    Text("\(reads[0].section_name)\n")
                    Text("\(reads[0].outline[0].context[7])\n")
                    Text("\(reads[0].day_messages[0].data[0].context[0])")
                }
                
            }
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
        dataManager.db.collection("stg-metadata").document("metadata").getDocument { document, error in
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
        let collection = "stg-data"
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
//    HomeVIew()
//}
