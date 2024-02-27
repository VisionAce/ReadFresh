//
//  AboutView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2024/2/25.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) var openURL
    @State private var colorData = ColorData()
    @State private var showEmail = false
    @State private var email = SupportEmail(toAddress: "ambitious4728@gmail.com",
                                            subject: "App問題回報",
                                            messageHeader: "請在以下描述您的問題")
    @AppStorage(UserDefaultsDataKeys.activateDarkMode) private var activateDarkMode = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("版本資訊") {
                    Text("您目前使用的iOS系統: \(UIDevice.current.systemVersion)")
                    Text("App版本: \(Bundle.main.appVersion)")
                    
                    
                    
                    
                }
                
                Section("資料來源") {
                    Link("部落格", destination: URL(string: "https://blog.udn.com/ymch130/article")!)
                    Link("新北市召會淡水會所", destination: URL(string: "https://churchintamsui.wixsite.com/index/morning-revival")!)
                }
                
                Section("聯絡方式") {
                    HStack {
                        Button {
                            if MailView.canSendMail {
                                showEmail.toggle()
                            } else {
                                print("""
                這個裝置不支援寄送電子郵件
                \(email.body)
                """
                                )
                            }
                        } label: {
                            HStack {
                                Image(systemName: "envelope.circle.fill")
                                    .resizable()
                                    .frame(width: 30,height: 30)
                                    .foregroundStyle(colorData.themeColor.gradient)
                                
                                Text("開發者信箱")
                                    .textSelection(.enabled)
                            }
                        }
                        
                    }
                    
                    HStack {
                        Image(.lineIcon)
                            .resizable()
                            .frame(width: 30,height: 30)
                        
                        Link("Line官方", destination: URL(string: "https://lin.ee/hqPBXDu")!)
                    }
                    
                    HStack {
                        Image(activateDarkMode ? .githubDark : .githubLight)
                            .resizable()
                            .frame(width: 30,height: 30)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        
                        Link("Github原始碼", destination: URL(string: "https://github.com/VisionAce/ReadFresh")!)
                    }
                    
                }
            }
            
            .navigationTitle("關於")
            .sheet(isPresented: $showEmail) {
                MailView(supportEmail: $email) { result in
                    switch result {
                    case .success:
                        print("Enail sent")
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                }
            }
            
        }
    }
}


#Preview {
    AboutView()
}
