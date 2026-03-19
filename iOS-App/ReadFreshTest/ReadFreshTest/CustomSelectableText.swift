//
//  CustomSelectableText.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2026/3/19.
//

import SwiftUI

class AutoSizingTextView: UITextView {
    // 覆寫「內部內容大小」的計算方式
    override var intrinsicContentSize: CGSize {
        // 給定目前的寬度，計算出可以完整容納所有文字的「真實高度」
        let size = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }
    
    // 每次畫面排版更新時，強制重新計算高度
    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}


// 建立一個包裝 UIKit UITextView 的 SwiftUI 元件
struct SelectableText: UIViewRepresentable {
    var text: String
    // 接收 SwiftUI 設定的變數
    var fontSize: Double
    var lineSpacing: Double
    
    func makeUIView(context: Context) -> AutoSizingTextView {
        let textView = AutoSizingTextView()
        // 允許選取文字
        textView.isSelectable = true
        // 禁止編輯（讓它看起來像純文字而不是輸入框）
        textView.isEditable = false
        // 關閉滾動，讓它可以適應 SwiftUI 的排版
        textView.isScrollEnabled = false
        // 移除預設的背景色和內邊距
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        // 設定預設字體大小
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        // 這告訴系統：當文字長度遇到螢幕邊緣時，請「妥協換行」，而不是硬撐著往右邊突破。
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        return textView
    }
    
    func updateUIView(_ uiView: AutoSizingTextView, context: Context) {
        // 先準備好新的段落樣式與屬性
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = CGFloat(lineSpacing)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        
        // 產出新的富文本
        let newAttributedText = NSAttributedString(string: text, attributes: attributes)
        
        // 【關鍵判斷】比對「目前的富文本」和「新的富文本」是否完全一致
        // 這樣不管是文字改變、字體改變、還是行距改變，只要有不同就會觸發更新
        if uiView.attributedText != newAttributedText {
            uiView.attributedText = newAttributedText
            // 通知系統重新計算高度
            uiView.invalidateIntrinsicContentSize()
        }
    }
}
