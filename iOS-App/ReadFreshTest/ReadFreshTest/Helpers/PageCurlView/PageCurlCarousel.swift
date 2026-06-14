//
//  PageCurlCarousel .swift
//  PageCurlView
//
//  Created by 褚宣德 on 2026/6/14.
//

import SwiftUI

struct PageCurlCarouselConfig {
    var curlRadius: CGFloat
    var curlShadow: CGFloat = 0.3
    var underneathShadow: CGFloat = 0.2
    var roundedRectangle: Self.RoundedRectangle = .init()
    var curlCenter: CGPoint = .init(x: 1, y: 0.5)
    
    struct RoundedRectangle {
        var topLeft: CGFloat = 0
        var topRight: CGFloat = 0
        var bottomLeft: CGFloat = 0
        var bottomRight: CGFloat = 0
    
        
    }
    
}

struct PageCurlCarousel<Content: View>: View {
    var config: PageCurlCarouselConfig
    @Binding var scrollProgress: CGFloat
    @Binding var currentPage: Int?
    @ViewBuilder var content: (CGSize) -> Content
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            // 🌟 核心修正：加入 ScrollViewReader，解除因 .visualEffect 導致原生 scrollPosition 失明的分頁控制問題
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        Group(subviews: content(size)) { collection in
                            ForEach(collection.indices, id: \.self) { index in
                                PageCurlItemView(
                                    index: index,
                                    size: size,
                                    config: config,
                                    scrollProgress: scrollProgress
                                ) {
                                    collection[index]
                                        .frame(width: size.width, height: size.height)
                                        .compositingGroup()
                                        .clipShape(
                                            UnevenRoundedRectangle(
                                                topLeadingRadius: config.roundedRectangle.topLeft,
                                                bottomLeadingRadius: config.roundedRectangle.bottomLeft,
                                                bottomTrailingRadius: config.roundedRectangle.bottomRight,
                                                topTrailingRadius: config.roundedRectangle.topRight
                                            )
                                        )
                                }
                                .visualEffect { content, proxy in
                                    let minX = proxy.frame(in: .scrollView(axis: .horizontal)).minX
                                    return content.offset(x: -minX)
                                }
                                .zIndex(Double(-index))
                                .id(index) // 精確綁定整數 ID
                            }
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                // 🌟 核心修正 1：手動滑動時，透過滾動幾何位移精準回傳當前頁碼給圓點指標
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    let width = geo.containerSize.width
                    guard width > 0 else { return 0 }
                    return geo.contentOffset.x / width
                } action: { oldValue, newValue in
                    scrollProgress = newValue
                    let calculatedPage = Int(round(newValue))
                    if currentPage != calculatedPage {
                        currentPage = calculatedPage
                    }
                }
                // 🌟 核心修正 2：監聽圓點控制鈕的點擊事件，在不衝突滑動手勢的前提下驅動跨頁面跳轉
                .onChange(of: currentPage) { _, newValue in
                    guard let newValue else { return }
                    let currentCalculatedPage = Int(round(scrollProgress))
                    // 只有當使用者點擊圓點（即滑動進度與點擊目標不符）時，才主動調用動畫滾動
                    if newValue != currentCalculatedPage {
                        withAnimation(.snappy(duration: 0.35, extraBounce: 0)) {
                            scrollProxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

fileprivate struct PageCurlItemView<Content: View>: View {
    var index: Int
    var size: CGSize
    var config: PageCurlCarouselConfig
    var scrollProgress: CGFloat
    @ViewBuilder var content: Content
    
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        content
            .layerEffect(
                ShaderLibrary.pageCurlEffect(
                    .float(dragOffset),
                    .float2(size.width, size.height),
                    .float4(
                        config.roundedRectangle.topLeft,
                        config.roundedRectangle.topRight,
                        config.roundedRectangle.bottomLeft,
                        config.roundedRectangle.bottomRight
                    ),
                    .float2(
                        size.width * config.curlCenter.x,
                        size.height * config.curlCenter.y
                    ),
                    .float(config.curlRadius),
                    .float(config.curlShadow),
                    .float(config.underneathShadow)
                ),
                maxSampleOffset: size
            )
            .onChange(of: scrollProgress) { _, newValue in
                let range = CGFloat(index)...CGFloat(index + 1)
                if range.contains(newValue) {
                    let progress = newValue - range.lowerBound
                    dragOffset = progress * (size.width + (self.config.curlRadius * 2))
                }
            }
    }
}
