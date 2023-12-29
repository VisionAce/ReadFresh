//
//  ReadData.swift
//  ReadFreshTest
//
//  Created by 褚宣德 on 2023/12/7.
//

import Foundation
import SwiftData

@Model
class ReadData_v2: Identifiable {
    @Attribute(.unique)var id: String
    var created_day: Date

    var day_messages = [DayMessage]()
    var ended_day: Date

    var outline = [ContextString]()
    var section_name: String
    var section_number: String
    var started_day: Date
    var training_name: String
    var training_topic: String
    var training_year: String
    var type: String
    
    init(id: String, created_day: Date, ended_day: Date, section_name: String, section_number: String, started_day: Date, training_name: String, training_topic: String, training_year: String, type: String) {
        self.id = id
        self.created_day = created_day
        self.ended_day = ended_day
        self.section_name = section_name
        self.section_number = section_number
        self.started_day = started_day
        self.training_name = training_name
        self.training_topic = training_topic
        self.training_year = training_year
        self.type = type
    }
}


