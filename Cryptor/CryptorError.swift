//
//  CryptorError.swift
//  TresorMockup4
//
//  Created by OKU Junichirou on 2021/01/16.
//

import Foundation
import CryptoKit
import CommonCrypto

public enum CryptorError: Error {
    case unexpected
    case outOfRange
    case invalidCharacter
    case wrongPassword
    case notOpened
    case alreadyOpened
    case notPrepared
    case alreadyRegistered
    case SecItemBroken
    case timeOut
    case sealError
    case CryptoKitError(error: CryptoKitError)
    case SecItemError(error: OSStatus)
}

extension CryptorError: LocalizedError {
    /// Returns a description of the error.
    public var errorDescription: String?  {
        switch self {
        case .unexpected:
            return "Unexpected Error"
        case .outOfRange:
            return "Out of Range"
        case .invalidCharacter:
            return "Invalid Character"
        case .wrongPassword:
            return "Wrong Password"
        case .notOpened:
            return "Cryptor is not Opened"
        case .alreadyOpened:
            return "Cryptor is already Opened"
        case .notPrepared:
            return "Prepare is not called"
        case .alreadyRegistered:
            return "Register is called twice"
        case .SecItemBroken:
            return "SecItem is broken"
        case .timeOut:
            return "Time Out to acquire a lock"
        case .sealError:
            return "AES.GCM.seal error"
        case .CryptoKitError(let error):
            return "CryptokitError(\(error)"
        case .SecItemError(let error):
            return "SecItem Error(\(error))"
        }
    }
}

// https://stackoverflow.com/questions/39972512/cannot-invoke-xctassertequal-with-an-argument-list-errortype-xmpperror
extension CryptorError: Equatable {
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// - Parameters:
    ///   - lhs: A left hand side expression.
    ///   - rhs: A right hand side expression.
    /// - Returns: `True` if `lhs` equals `rhs`, otherwise `false`.
    public static func == (lhs: CryptorError, rhs: CryptorError) -> Bool {
        switch (lhs, rhs) {
        case (.unexpected,         .unexpected),
             (.outOfRange,         .outOfRange),
             (.invalidCharacter,   .invalidCharacter),
             (.wrongPassword,      .wrongPassword),
             (.notOpened,          .notOpened),
             (.alreadyRegistered,  .alreadyRegistered),
             (.alreadyOpened,      .alreadyOpened),
             (.notPrepared,        .notPrepared),
             (.SecItemBroken,      .SecItemBroken),
             (.timeOut,            .timeOut),
             (.sealError,          .sealError):
            return true
        case (.CryptoKitError(let error1), .CryptoKitError(let error2)):
            return error1.localizedDescription  == error2.localizedDescription
        case (.SecItemError(let error1), .SecItemError(let error2)):
            return error1 == error2
        default:
            return false
        }
    }
}
