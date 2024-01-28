//
//  ColorData.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2024/1/28.
//

import SwiftUI

struct ColorData {
    private var COLOR_KEY = ColorThemeKey.COLOR_KEY
    private let userDefults = UserDefaults.standard
    
    var uiColor: UIColor {
        let result = loadColor()
        return UIColor(result)
    }
    
    var themeColor: Color {
        return loadColor()
    }
    
    func saveColor(color: Color) {
        let color = UIColor(color).cgColor
        
        if let components = color.components {
            userDefults.set(components, forKey: COLOR_KEY)
//            print(components)
//            print("Color saved!")
        }
    }
    
    func loadColor() -> Color {
        guard let array = userDefults.object(forKey: COLOR_KEY) as? [CGFloat] else { return Color.brown }
        
        let color = Color(.sRGB,
                          red: array[0],
                          green: array[1],
                          blue: array[2],
                          opacity: array[3])
//        print(color)
//        print("Color loaded!")
        return color
    }
}
