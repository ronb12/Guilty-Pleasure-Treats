//
//  Date+Formatting.swift
//  Guilty Pleasure Treats
//

import Foundation

extension Date {
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: self)
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    var dateAndTimeString: String {
        "\(shortDateString) at \(timeString)"
    }
}
