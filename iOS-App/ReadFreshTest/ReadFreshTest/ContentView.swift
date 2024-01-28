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
    
    @State private var activeTab: Tab = .thisWeek
    /// For Smooth Shape Sliding Effect, We're going to use Matched Geometry Effect
    @Namespace private var animation
    @State private var tabShapePosition: CGPoint = .zero
    
    //  TelegramDarkModeAnimation
    @AppStorage(UserDefaultsDataKeys.toggleDarkMode) private var toggleDarkMode = false
    @AppStorage(UserDefaultsDataKeys.activateDarkMode) private var activateDarkMode = false
    @State private var buttonRect: CGRect = .zero
    /// Current & Previous State Images
    @State private var currengeImage: UIImage?
    @State private var preiousImage: UIImage?
    @State private var maskAnimation: Bool = false
    
    private var colorData = ColorData()
//    @State private var lastRefreshTime: Date?
    
    init() {
        /// Hiding Tab Bar Due To SwiftUI iOS 16 Bug
        UITabBar.appearance().isHidden = true
        /// Modifying Refresh Control
        UIRefreshControl.appearance().attributedTitle = NSAttributedString(string: "下拉更新...")
    }
    
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
                VStack(spacing: 0) {
                    TabView(selection: $activeTab) {
                        MessageView()
                            .tag(Tab.thisWeek)
                        
                        PastMessage()
                            .tag(Tab.pastWeek)
                        
                        
                        SettingView(reads: reads)
                            .tag(Tab.setting)
                        
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        customTabBar()
                    }
                }
                
                .createImages(toggleDarkMode: toggleDarkMode,
                              currentImage: $currengeImage,
                              previousImage: $preiousImage,
                              activateDarkMode: $activateDarkMode)
                .overlay(content: {
                    GeometryReader(content: { geometry in
                        let size = geometry.size
                        
                        if let preiousImage, let currengeImage {
                            ZStack {
                                Image(uiImage: preiousImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: size.width, height: size.height)
                                
                                Image(uiImage: currengeImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: size.width, height: size.height)
                                    .mask(alignment: .topLeading) {
                                        Circle()
                                            .frame(width: buttonRect.width * (maskAnimation ? 80 : 1), height: buttonRect.height * (maskAnimation ? 80 : 1), alignment: .bottomLeading)
                                            .frame(width: buttonRect.width, height: buttonRect.height)
                                            .offset(x: buttonRect.minX, y: buttonRect.minY)
                                            .ignoresSafeArea()
                                        
                                    }
                            }
                            .task {
                                guard !maskAnimation else { return }
                                withAnimation(.easeInOut(duration: 0.9), completionCriteria: .logicallyComplete) {
                                    maskAnimation = true
                                } completion: {
                                    /// Removing all snapshots
                                    self.currengeImage = nil
                                    self.preiousImage = nil
                                    maskAnimation = false
                                }
                            }
                        }
                    })
                    /// Reverse Masking
                    .mask({
                        Rectangle()
                            .overlay(alignment: .topLeading) {
                                Circle()
                                    .frame(width: buttonRect.width, height: buttonRect.height)
                                    .offset(x: buttonRect.minX, y: buttonRect.minY)
                                    .blendMode(.destinationOut)
                            }
                    })
                    .ignoresSafeArea()
                })
                .overlay(alignment: .topTrailing) {
                    
                    Button(action: {
                        toggleDarkMode.toggle()
                    }, label: {
                        Image(systemName: toggleDarkMode ? "sun.max.fill" : "moon.fill")
                            .font(.title2)
                            .foregroundStyle(Color.primary)
                            .symbolEffect(.bounce, value: toggleDarkMode)
                            .frame(width: 40, height: 40)
                            .opacity(activeTab == .setting ? 1 : 0)
                    })
                    .rect { rect in
                        buttonRect = rect
                    }
                    .padding(10)
                    .disabled(currengeImage != nil || preiousImage != nil || maskAnimation || activeTab != .setting)
                }
                .preferredColorScheme(activateDarkMode ? .dark : .light)
                
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
        .refreshable {
            
//            let currentTime = Date()
//            guard let lastTime = lastRefreshTime, currentTime.timeIntervalSince(lastTime) > 1.0 else {
//                return  // 短时间内不执行刷新
//            }
//            lastRefreshTime = currentTime
            onRefresh()
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
        checkRemoteVersionTaskCompleted = false
    }
    
    func onRefresh() {
        withAnimation {
            checkRemoteVersionTask { }
            if checkRemoteVersionTaskCompleted {
                loadDataTask()
            }
        }
    }
    
    
    /// Custom Tab Bar
    ///  With More Easy Customization
    @ViewBuilder
    func customTabBar(_ tint: Color = .brown, _ inactiveTint: Color = .orange) -> some View {
        /// Moving all the Remaining Tab Item's to Bottom
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) {
                TabItem(tint: colorData.themeColor,
                        inactiveTint: inactiveTint,
                        tab: $0,
                        animation: animation,
                        activeTab: $activeTab,
                        position: $tabShapePosition)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 2)
        .background(content: {
            TabShape(midpoint: tabShapePosition.x)
                .fill(.windowBackground)
                .ignoresSafeArea()
            /// Adding Blur + Shadow
            /// For shape Smoothening
                .shadow(color: colorData.themeColor.opacity(0.2), radius: 5, x: 0, y: -5)
                .blur(radius: 2)
                .padding(.top, 25)
        })
        .animation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7), value: activeTab)
    }
    
}

/// Tab Bar Item
struct TabItem: View {
    var tint: Color
    var inactiveTint: Color
    var tab: Tab
    var animation: Namespace.ID
    @Binding var activeTab: Tab
    @Binding var position: CGPoint
    @State private var tabPosition: CGPoint = .zero
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: tab.systemImage)
                .font(.title2)
                .foregroundStyle(activeTab == tab ? .white : tint)
            /// Increasing size for the Active Tab
                .frame(width: activeTab == tab ? 58 : 35, height: activeTab == tab ? 58 : 35)
                .background {
                    if activeTab == tab {
                        Circle()
                            .fill(tint.gradient)
                            .matchedGeometryEffect(id: "ACTIVETAB", in: animation)
                    }
                }
            
            Text(tab.rawValue)
                .font(.caption)
                .foregroundStyle(activeTab == tab ? tint : .gray)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .viewPosition(completion: { rect in
            tabPosition.x = rect.midX
            
            /// Updating Active Tab Position
            if activeTab == tab {
                position.x = rect.midX
            }
        })
        .onTapGesture {
            activeTab = tab
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.7)) {
                position.x = tabPosition.x
            }
        }
    }
}


//#Preview {
//    ContentView()
//}
