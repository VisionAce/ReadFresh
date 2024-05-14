//
//  AppStoreVersionView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2024/5/14.
//

import SwiftUI

enum LoadingState {
    case loading, loaded, failed
}


struct AppStoreVersionView: View {
    // Enforced Updating Version
    @State private var loadingState: LoadingState = .loading
    @State private var appStoreVersion = ""
    @State private var update = false

    let localVersion = Bundle.main.appVersion
    
    var body: some View {
        Group {
            
            if appStoreVersion.versionCompare(localVersion) == .orderedDescending {
              EmptyView()
            } else  {
                ContentView()
            }
        
        }
        .alert("有新的版本唷!\n歡迎更新~", isPresented: $update) {
            Link("前往更新", destination: URL(string: "https://apps.apple.com/tw/app/god-morning/id6476152119")!)
        }
        .task {
                await fetchAppStoreVersion()
            if appStoreVersion.versionCompare(localVersion) == .orderedDescending {
                print("需要更新")
                print("AppStore: \(appStoreVersion) local: \(localVersion)")
                update = true
            } else if appStoreVersion.versionCompare(localVersion) == .orderedSame {
                print("版本相同")
                print("AppStore: \(appStoreVersion) local: \(localVersion)")
                update = false
            } else if appStoreVersion.versionCompare(localVersion) == .orderedAscending {
                print("版本超前")
                print("AppStore: \(appStoreVersion) local: \(localVersion)")
            }
        }
            
    }
    
    func fetchAppStoreVersion() async {
        let bundleID = Bundle.main.bundleIdentifier!
        print(bundleID)
        let urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleID)"
        
        guard let url = URL(string: urlString) else {
            print("Bad URL: \(urlString)")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let items = try JSONDecoder().decode(AppStoreData.self, from: data)
            for result in items.results {
                appStoreVersion = result.version
            }
            
            loadingState = .loaded
        } catch {
            loadingState = .failed
        }
    }
    
}
 
