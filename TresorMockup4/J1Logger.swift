//
//  J1Logger.swift
//  TresorMockup3
//
//  Created by OKU Junichirou on 2020/11/02.
//

import Foundation
import os

internal class J1Logger {
    static  let shared = J1Logger()
    private var logger_debug:  Logger
    private var logger_info:   Logger
    private var logger_notice: Logger
    private var logger_error:  Logger
    private var logger_fault:  Logger
    
    init() {
        let ssys = Bundle.main.bundleIdentifier ?? "nil"
        self.logger_debug  = Logger(subsystem: ssys, category: "DEBUG")
        self.logger_info   = Logger(subsystem: ssys, category: "INFO")
        self.logger_notice = Logger(subsystem: ssys, category: "NOTICE")
        self.logger_error  = Logger(subsystem: ssys, category: "ERROR")
        self.logger_fault  = Logger(subsystem: ssys, category: "FAULT")
    }
    
    private func format(file: String) -> (String, String) {
        let th = Thread.current.isMainThread ? "main" : (Thread.current.name ?? "")
        let fl = URL(string: file)?.deletingPathExtension().path ?? ""
        return (th, fl)
    }
    
    internal func debug(_ message: @autoclosure () -> String,
                        file:     String = #fileID,
                        function: String = #function,
                        line:     Int = #line) {
        let (th, fl) = self.format(file: file)
        let msg = message()
        self.logger_debug.debug("\(th) \(fl).\(function):\(line) - \(msg)")
    }
    
    internal func info(_ message: @autoclosure () -> String,
                       file:     String = #fileID,
                       function: String = #function,
                       line:     Int = #line) {
        let (th, fl) = self.format(file: file)
        let msg = message()
        self.logger_info.info("\(th) \(fl).\(function):\(line) - \(msg)")
    }
    
    internal func notice(_ message: @autoclosure () -> String,
                         file:     String = #fileID,
                         function: String = #function,
                         line:     Int = #line) {
        let (th, fl) = self.format(file: file)
        let msg = message()
        self.logger_notice.notice("\(th) \(fl).\(function):\(line) - \(msg)")
    }
    
    internal func error(_ message: @autoclosure () -> String,
                        file:     String = #fileID,
                        function: String = #function,
                        line:     Int = #line) {
        let (th, fl) = self.format(file: file)
        let msg = message()
        self.logger_error.error("\(th) \(fl).\(function):\(line) - \(msg)")
    }
    
    internal func fault(_ message: @autoclosure () -> String,
                        file:     String = #fileID,
                        function: String = #function,
                        line:     Int = #line) {
        let (th, fl) = self.format(file: file)
        let msg = message()
        self.logger_fault.fault("\(th) \(fl).\(function):\(line) - \(msg)")
    }
}
