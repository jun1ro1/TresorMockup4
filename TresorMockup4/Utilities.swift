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

//// https://stackoverflow.com/questions/61238773/how-can-i-initialize-view-again-in-swiftui/61242931#61242931
//class DeferedConstructor<T: ObservableObject> {
//    var constructor: () -> T
//    
//    init(_ constructor: @autoclosure @escaping () -> T) {
//        self.constructor = constructor
//    }
//    
//    func construct() -> T {
//        return self.constructor()
//    }
//}
