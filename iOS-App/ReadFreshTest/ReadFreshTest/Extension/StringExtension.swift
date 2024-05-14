//
//  Extension.swift
//  VersionUpdateAppStore
//
//  Created by 褚宣德 on 2024/5/14.
//

import SwiftUI

extension String {
    func versionCompare(_ otherVersion: String) -> ComparisonResult {
        var v1 = versionComponents()
        var v2 = otherVersion.versionComponents()
        let diff = v1.count - v2.count
        
        if diff == 0 {
            return self.compare(otherVersion, options: .numeric)
        }
        
        if diff > 0 {
            v2.append(contentsOf: (0..<diff).map { _ in "0" })
        } else {
            v1.append(contentsOf: (0..<abs(diff)).map { _ in "0" })
        }
        
        return v1.joined().compare(v2.joined())
    }
    
    func versionComponents() -> [String] {
        components(separatedBy: ".")
    }
}
