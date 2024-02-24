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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("版本資訊") {
                    Text("您目前使用的iOS系統: \(UIDevice.current.systemVersion)")
                    Text("App版本: \(Bundle.main.appVersion)")
                    
                    
                    Link("資料來源", destination: URL(string: "https://blog.udn.com/ymch130/article")!)
                    
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
                                    .font(.title)
                                    .foregroundStyle(colorData.themeColor.gradient)
                            }
                        }
                        Text("ambotious4728@gmail.com")
                            .textSelection(.enabled)
                    }
                    
                    HStack {
                        Image(.lineIcon)
                            .resizable()
                            .frame(width: 30,height: 30)
                        
                        Link("Line", destination: URL(string: "https://lin.ee/hqPBXDu")!)
                    }
                    
                    HStack {
                        Image(.github)
                            .resizable()
                            .frame(width: 30,height: 30)
                        
                        Link("Github", destination: URL(string: "https://github.com/VisionAce/ReadFresh")!)
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
