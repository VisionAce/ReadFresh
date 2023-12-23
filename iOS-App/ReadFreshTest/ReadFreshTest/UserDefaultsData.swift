//
//  UserDefaultsData.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/22.
//

import Foundation

class localVersionUserDefaultsData: ObservableObject {
    let defaults = UserDefaults.standard
    var value: Int = 0
    private let saveKey = UserDefaultsDataKeys.localVersion
    
    
    init() {
        if UserDefaults.standard.object(forKey: saveKey) != nil {
            value = UserDefaults.standard.integer(forKey: saveKey)
        }
        
    }
    
    func save(saveValue: Int) {
        defaults.set(saveValue, forKey: saveKey)
    }
    
}


enum UserDefaultsDataKeys {
    static let localVersion = "localVersion"
}
