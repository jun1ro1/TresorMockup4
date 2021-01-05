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

func getDomain(from urlString: String?) -> String? {
    let slds: [String] = ["ac", "ad", "co", "ed", "go", "gr", "lg", "ne", "or"]
    guard urlString != nil else {
        return nil
    }
    guard let url = URL(string: urlString!) else {
        return nil
    }
    let host   = url.host
    guard host != nil else {
        return nil
    }
    
    var words  = host!.split(separator: ".")
    words.reverse()
    let count  = words.count
    var domain = ""
    if words[0].lowercased() == "com" {
        var a = words[0...1]
        a.reverse()
        domain = a.joined(separator: ".")
    }
    else if count > 2 && slds.contains(where: { $0 == words[1].lowercased() }) {
        var a = words[0...2]
        a.reverse()
        domain = a.joined(separator: ".")
    }
    else {
        domain = host!
    }
    return domain
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
