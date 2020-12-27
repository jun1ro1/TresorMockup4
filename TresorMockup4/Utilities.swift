//
//  Utilities.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2020/12/26.
//

import Foundation

func update<T: Comparable>(_ variable:inout T?, with value: T) {
    if variable != value {
        variable = value
    }
}
