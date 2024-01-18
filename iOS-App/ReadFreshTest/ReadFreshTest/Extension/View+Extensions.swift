//
//  View+Extensions.swift
//  TelegramDarkModeAnimation
//
//  Created by 褚宣德 on 2024/1/11.
//

import SwiftUI

/// Custom View Extension
extension View {
    @ViewBuilder
    func rect(value: @escaping(CGRect) -> ()) -> some View {
        self
            .overlay {
                
                GeometryReader(content: { geometry in
                    let rect = geometry.frame(in: .global)
                    
                    Color.clear
                        .preference(key: RectKey.self, value: rect)
                        .onPreferenceChange(RectKey.self ,perform: { rect in
                            value(rect)
                        })
                })
            }
    }
    
    @MainActor
    @ViewBuilder
    func createImages(toggleDarkMode: Bool, currentImage: Binding <UIImage?>, previousImage: Binding<UIImage?>, activateDarkMode: Binding<Bool>) -> some View {
        self
            .onChange(of: toggleDarkMode) { oldValue, newValue in
                Task {
                    if let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) {
                        let imageView = UIImageView()
                        imageView.frame = window.frame
                        imageView.image = window.rootViewController?.view.image(window.frame.size)
                        imageView.contentMode = .scaleAspectFit
                        window.addSubview(imageView)
                        
                        if let rootView = window.rootViewController?.view {
                            let framSize = window.frame.size
                            /// Creating Snapshots
                            ///  Old One
                            activateDarkMode.wrappedValue = !newValue
                            previousImage.wrappedValue = rootView.image(framSize)
                            /// New One with Updated Trait State
                            activateDarkMode.wrappedValue = newValue
                            /// Giving some time to complete tje transition
                            try await Task.sleep(for: .seconds(0.01))
                            currentImage.wrappedValue = rootView.image(framSize)
                            /// Removing once all the snapshots has taken
                            try await Task.sleep(for: .seconds(0.01))
                            imageView.removeFromSuperview()
                        }
                    }

                }
            }
    }
}

/// Converting UIView to UIImage
extension UIView {
    func image(_ size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            drawHierarchy(in: .init(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }
}
