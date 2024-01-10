//
//  ScrollDetector.swift
//  AnimatedStickyHeader
//
//  Created by 褚宣德 on 2024/1/9.
//

import SwiftUI

/// Extracting UIScrollView from SwiftUI ScrollView for monitoring offset and velocity
struct ScrollDetector: UIViewRepresentable {
    var onScroll: (CGFloat) -> ()
    /// Offset, Velocity
    var onDraggingEnd: (CGFloat, CGFloat) -> ()
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> some UIView {
        return UIView()
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        DispatchQueue.main.async {
            // uiView -> Background ; superview? -> .Background {} ; superview? -> VStack {} ; superview -> ScrollView {}
            /// Adding Delegate for only one time
            if let scrollview = uiView.superview?.superview?.superview as? UIScrollView, !context.coordinator.isDelegateAdded {
                /// Adding Delegate
                scrollview.delegate = context.coordinator
                context.coordinator.isDelegateAdded = true
            }
        }
    }
    
    /// ScrollView Delegate Methods
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ScrollDetector
        init(parent: ScrollDetector) {
            self.parent = parent
        }
        
        /// One time Delegate Initialization
        var isDelegateAdded: Bool = false
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            parent.onScroll(scrollView.contentOffset.y)
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            parent.onDraggingEnd(targetContentOffset.pointee.y, velocity.y)
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let velocity = scrollView.panGestureRecognizer.velocity(in: scrollView.panGestureRecognizer.view)
            parent.onDraggingEnd(scrollView.contentOffset.y, velocity.y)
        }
    }
}
