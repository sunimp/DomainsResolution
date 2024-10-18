//
//  ABI.swift
//  DomainsResolution
//
//  Created by Sun on 2021/2/16.
//

import Foundation

import Foundation

// MARK: - ABI

public struct ABI { }

// MARK: - ABIElementPropertiesProtocol

protocol ABIElementPropertiesProtocol {
    var isStatic: Bool { get }
    var isArray: Bool { get }
    var isTuple: Bool { get }
    var arraySize: ABI.Element.ArraySize { get }
    var subtype: ABI.Element.ParameterType? { get }
    var memoryUsage: UInt64 { get }
    var emptyValue: Any { get }
}

// MARK: - ABIEncoding

protocol ABIEncoding {
    var abiRepresentation: String { get }
}

// MARK: - ABIValidation

protocol ABIValidation {
    var isValid: Bool { get }
}
