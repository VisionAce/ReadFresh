//
//  ArticleView.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2024/1/9.
//

import SwiftUI

struct ArticleView: View {
    var size: CGSize
    var safeArea: EdgeInsets
    let read : ReadData_v2
    /// View Properties
    @State private var offsetY: CGFloat = 0
    @State private var dayPicker = "綱要"
    @AppStorage(UserDefaultsDataKeys.fontSize) private var fontSize: Double = 18.0
    
    var days: [String] {
        var res = ["綱要"]
        for title in read.day_messages {
            res.append(title.day)
        }
        return res
    }
    
    var body: some View {
        ScrollViewReader { scrolllProxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    HeaderView()
                    /// Making to Top
                        .zIndex(1000)
                    DayMessageView(read: read, dayPicker: dayPicker)
                        .padding(.horizontal)
                }
                .id(ViewIDKeys.scrollviewID)
                .background {
                    ScrollDetector { offset in
                        offsetY = -offset
                    } onDraggingEnd: { offset, velocity in
                        /// Resetting to initial State, if not Completely Scrolled
                        let headerHeight = (size.height * 0.3) + safeArea.top
                        let minimumHeaderHeight = 65 + safeArea.top
                        
                        let targetEnd = offset + (velocity * 45)
                        if targetEnd < (headerHeight - minimumHeaderHeight) && targetEnd > 0 {
                            withAnimation(.interactiveSpring(response: 0.55, dampingFraction: 0.65, blendDuration: 0.65)) {
                                scrolllProxy.scrollTo(ViewIDKeys.scrollviewID, anchor: .top)
                            }
                        }
                    }

                }
            }
            
        }
        .font(.system(size: fontSize))
    }
    
    /// Header View
    @ViewBuilder
    func HeaderView() -> some View {
        let headerHeight = (size.height * 0.3) + safeArea.top
        let minimumHeaderHeight = 55 + safeArea.top
        /// Converting Offset into Progress
        /// Limiting it to 0 - 1
        let progress = min(1,max(0,(-offsetY / (headerHeight - minimumHeaderHeight))))
        GeometryReader { _ in
            ZStack {
                UnevenRoundedRectangle(cornerRadii: .init(
                    topLeading: 10,
                    topTrailing: 10
                ))
                    .fill(.brown.gradient)
                
                VStack(spacing: 10) {
                    
                    TitleIView(read: read)
                        .padding(.horizontal)
                    
                    Picker("Day", selection: $dayPicker) {
                        ForEach(days, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(.palette)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        /// Scaling Text Little Bit
                        .scaleEffect(1 - (progress * 0.05))
                        /// Moving Text Little Bit
                        /// 3 -> 10 (Spacing) ; 0.3 (Image Scaling)
                        .offset(y: -3 * progress)
                }
                .padding(.top, safeArea.top)
                .padding(.bottom, 10)
            }
            /// Resizing Header
            .frame(height: (headerHeight + offsetY) < minimumHeaderHeight ? minimumHeaderHeight :  (headerHeight + offsetY), alignment: .bottom)
            /// Sticking to the Top
            .offset(y: -offsetY)

        }
        .frame(height: headerHeight)
        
    }
    
}
