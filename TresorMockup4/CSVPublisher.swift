//
//  CSVPublisher.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/03/13.
//

import Foundation
import Combine
import CSV

class CSVPublisher: NSObject {
    private var subjectPrivate = PassthroughSubject<Dictionary<String, String>, Error>()
    
    var subject: PassthroughSubject<Dictionary<String, String>, Error> {
        get {
            return self.subjectPrivate
        }
    }
        
    func start(url: URL) {
        guard let stream = InputStream(url: url) else {
            J1Logger.shared.error("InputStream error url=\(url)")
            self.subjectPrivate.send(completion: .failure(NSCoderValueNotFoundError as! Error))
            return
        }
        
        let csv: CSVReader
        do {
            csv = try CSVReader(stream: stream, hasHeaderRow: true)
        } catch let error {
            J1Logger.shared.error("CSVReader fails=\(error)")
            self.subjectPrivate.send(completion: .failure(error))
            return
        }
        guard let header = csv.headerRow else {
            J1Logger.shared.error("header not found")
            self.subjectPrivate.send(completion: .failure(NSCoderValueNotFoundError as! Error))
            return
        }
        
        while let row = csv.next() {
            let dict = Dictionary(uniqueKeysWithValues: zip(header, row))
            print("send")
            self.subjectPrivate.send(dict)
        }
        self.subjectPrivate.send(completion: .finished)
    }
}