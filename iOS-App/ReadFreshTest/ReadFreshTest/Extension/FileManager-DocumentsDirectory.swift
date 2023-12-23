//
//  FileManager-DocumentsDirectory.swift
//  BucketList
//
//  Created by 褚宣德 on 2023/11/11.
//

import Foundation

extension FileManager {
    static var documentsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}


