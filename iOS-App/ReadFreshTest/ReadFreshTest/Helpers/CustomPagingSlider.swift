//
//  CustomPagingSlider.swift
//  PagingControl
//
//  Created by 褚宣德 on 2024/1/1.
//

import SwiftUI

/// Paging Slider Data Model
struct Item: Identifiable {
    private(set) var id: UUID = .init()
    var color: Color
    var title: String
    var subTitle: String
}


/// Custom View
struct CustomPagingSlider<Content: View, TitleContent: View, Item: RandomAccessCollection>: View where Item: MutableCollection, Item.Element: Identifiable {
    /// Customization Properties
    var showsIndicator: ScrollIndicatorVisibility = .hidden
    var showPagingControl: Bool = true
    var disablepagingInteraction: Bool = false
    var titleScrollSpeed: CGFloat = 0.6
    var pagingControlSpacing: CGFloat = 20
    var spacing: CGFloat = 10
    
    @Binding var data: Item
    @ViewBuilder var content: (Binding<Item.Element>) -> Content
    @ViewBuilder var titleContent: (Binding<Item.Element>) -> TitleContent
    /// View Properties
    @State private var activeID: UUID?
    
    var body: some View {
        // 🌟 核心修正：在主執行緒先將屬性導出為本地常數，供下方的非隔離閉包安全捕獲
        let speed = titleScrollSpeed
        
        VStack(spacing: pagingControlSpacing) {
            ScrollView(.horizontal) {
                HStack(spacing: spacing) {
                    ForEach($data) { item in
                        VStack(spacing: 0) {
                            titleContent(item)
                                .frame(maxWidth: .infinity)
                                .visualEffect { content, geometryProxy in
                                    // 🌟 核心修正：直接在內部計算，避免跨 Actor 呼叫方法
                                    let minX = geometryProxy.bounds(of: .scrollView)?.minX ?? 0
                                    return content
                                        .offset(x: -minX * speed)
                                }
                            
                            content(item)
                        }
                        // 取代了 GeometryReader 來算出每頁畫面所需的空間
                        .containerRelativeFrame(.horizontal)
                    }
                }
                /// Adding Paging
                .scrollTargetLayout()
            }
            .scrollIndicators(showsIndicator)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $activeID)
            
            if showPagingControl {
                PagingControl(numberOfPages: data.count, activePage: activePage) { value in
                /// Updating to current Page
                    if let index = value as? Item.Index, data.indices.contains(index) {
                        if let id = data[index].id as? UUID {
                            withAnimation(.snappy(duration: 0.35, extraBounce: 0)) {
                                activeID = id
                            }
                        }
                    }
                }
                .disabled(disablepagingInteraction)
            }
        }
    }
    
    var activePage: Int {
        if let index = data.firstIndex(where: { $0.id as? UUID == activeID }) as? Int {
            return index
        }
        return 0
    }
}

/// Let's Add Paging Control
struct PagingControl: UIViewRepresentable {
    var numberOfPages: Int
    var activePage: Int
    var onPageChange: (Int) -> ()
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(onPageChange: onPageChange)
    }
    
    func makeUIView(context: Context) -> UIPageControl {
        let view = UIPageControl()
        view.currentPage = activePage
        view.numberOfPages = numberOfPages
        view.backgroundStyle = .prominent
        view.currentPageIndicatorTintColor = UIColor(Color.primary)
        view.pageIndicatorTintColor = UIColor.placeholderText
        view.addTarget(context.coordinator, action: #selector(Coordinator.onPageUpdate(control:)), for: .valueChanged)
        return view
    }
    
    func updateUIView(_ uiView: UIPageControl, context: Context) {
       /// Updating Outside Event Changes
        uiView.numberOfPages = numberOfPages
        uiView.currentPage = activePage
    }
    
    class Coordinator: NSObject {
        var onPageChange: (Int) -> ()
        init(onPageChange: @escaping (Int) -> Void) {
            self.onPageChange = onPageChange
        }
        @objc
        func onPageUpdate(control: UIPageControl) {
            onPageChange(control.currentPage)
        }
    }
}
