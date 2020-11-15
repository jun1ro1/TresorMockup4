//
//  CryptorExtensions.swift
//  TresorMockup3
//
//  Created by OKU Junichirou on 2020/11/05.
//

import Foundation
import CryptoKit

public extension Data {
    func encrypt(using key: SymmetricKey) throws -> Data {
        let cipher = try AES.GCM.seal(self, using: key)
        guard cipher.combined != nil else {
            throw CryptorError.sealError
        }
        return cipher.combined!
    }
 
    func decrypt(using key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: self)
        return try AES.GCM.open(box, using: key) // excep
    }

    func hash() -> Data {
        let h = SHA256.hash(data: self)
        return h.withUnsafeBytes() {
            return Data($0)
        }
    }

    mutating func reset() {
        self.resetBytes(in: self.startIndex..<self.endIndex)
    }
    
    static let Zero = Data(count:1)
    
    var isZero: Bool { return self.first(where: {$0 != 0}) == nil }
    
    // Big Endian
    mutating func zerosuppressed() -> Data {
        if let idx = self.firstIndex(where: {$0 != 0}) {
            self.removeFirst(Int(idx))
        }
        else {
            self = Data(count:1)
        }
        return self
    }
    
    func divide(by divisor: UInt8) -> (Data, UInt8) {
        guard divisor != 0 else {
            return ( Data(), UInt8(0) )
        }
        var dividend = self.reduce(
            into: (Data(capacity:self.count), 0),
            { (result, value) in
                var (quotinent, remainder) = result
                let x: Int = remainder * 0x100 + Int(value)
                quotinent.append( UInt8(x / Int(divisor)) )
                remainder = x % Int(divisor)
                result = (quotinent, remainder)
            }
        )
        return (dividend.0.zerosuppressed(), UInt8(dividend.1))
    }

    func als(radix: UInt8) -> Data {
        var dividend = self
        var data = Data(capacity:self.count)
        while !dividend.isZero {
            let (quotinent, remainder) = dividend.divide(by: radix)
            data.append(remainder)
            dividend = quotinent
        }
        return data.isZero ? Data(count:1) : Data(data.reversed())
    }

} // extension Data


public extension String {
    func decrypt(using key: SymmetricKey) throws -> Data {
        guard let data = Data(base64Encoded: self, options: .ignoreUnknownCharacters) else {
            throw CryptorError.invalidCharacter
        }
        return try data.decrypt(using: key)
    }

    func encrypt(using key: SymmetricKey) throws -> String {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else {
            throw CryptorError.invalidCharacter
        }
        return try data.encrypt(using: key).base64EncodedString()
    }

    func decrypt(using key: SymmetricKey) throws -> String {
        guard var data = Data(base64Encoded: self, options: []) else {
            throw CryptorError.invalidCharacter
        }
        defer { data.reset() }
        return String(data: try data.decrypt(using: key), encoding: .utf8)!
    }
} // extension String

public extension SymmetricKey {
    var data: Data {
        return self.withUnsafeBytes() { return Data($0) }
    }
    
    mutating func reset() {
        self = SymmetricKey(data: Data())
    }
}

