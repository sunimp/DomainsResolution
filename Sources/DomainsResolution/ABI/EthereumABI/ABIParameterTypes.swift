//
//  ABIParameterTypes.swift
//  DomainsResolution
//
//  Created by Sun on 2021/2/16.
//

import BigInt
import Foundation

// MARK: - ABI.Element.ParameterType

extension ABI.Element {
    /// Specifies the type that parameters in a contract have.
    public enum ParameterType: ABIElementPropertiesProtocol {
        case uint(bits: UInt64)
        case int(bits: UInt64)
        case address
        case function
        case bool
        case bytes(length: UInt64)
        indirect case array(type: ParameterType, length: UInt64)
        case dynamicBytes
        case string
        indirect case tuple(types: [ParameterType])

        // MARK: Computed Properties

        var isStatic: Bool {
            switch self {
            case .string:
                return false

            case .dynamicBytes:
                return false

            case let .array(type: type, length: length):
                if length == 0 {
                    return false
                }
                if !type.isStatic {
                    return false
                }
                return true

            case let .tuple(types: types):
                for t in types {
                    // swiftlint:disable for_where
                    if !t.isStatic {
                        return false
                    }
                }
                return true

            case .bytes(length: _):
                return true

            default:
                return true
            }
        }

        var isArray: Bool {
            switch self {
            case .array(type: _, length: _):
                true
            default:
                false
            }
        }

        var isTuple: Bool {
            switch self {
            case .tuple:
                true
            default:
                false
            }
        }

        var subtype: ABI.Element.ParameterType? {
            switch self {
            case .array(type: let type, length: _):
                type
            default:
                nil
            }
        }

        var memoryUsage: UInt64 {
            switch self {
            case let .array(_, length: length):
                if length == 0 {
                    return 32
                }
                if isStatic {
                    return 32 * length
                }
                return 32

            case let .tuple(types: types):
                if !isStatic {
                    return 32
                }
                var sum: UInt64 = 0
                for t in types {
                    sum += t.memoryUsage
                }
                return sum

            default:
                return 32
            }
        }

        var emptyValue: Any {
            switch self {
            case .uint(bits: _):
                return BigUInt(0)

            case .int(bits: _):
                return BigUInt(0)

            case .address:
                return EthereumAddress("0x0000000000000000000000000000000000000000")

            case .function:
                return Data(repeating: 0x00, count: 24)

            case .bool:
                return false

            case let .bytes(length: length):
                return Data(repeating: 0x00, count: Int(length))

            case let .array(type: type, length: length):
                let emptyValueOfType = type.emptyValue
                return Array(repeating: emptyValueOfType, count: Int(length))

            case .dynamicBytes:
                return Data()

            case .string:
                return ""

            case .tuple(types: _):
                return [Any]()
            }
        }

        var arraySize: ABI.Element.ArraySize {
            switch self {
            case .array(type: _, length: let length):
                if length == 0 {
                    return ArraySize.dynamicSize
                }
                return ArraySize.staticSize(length)

            default:
                return ArraySize.notArray
            }
        }
    }
}

// MARK: - ABI.Element.ParameterType + Equatable

extension ABI.Element.ParameterType: Equatable {
    public static func == (lhs: ABI.Element.ParameterType, rhs: ABI.Element.ParameterType) -> Bool {
        switch (lhs, rhs) {
        case let (.uint(length1), .uint(length2)):
            length1 == length2
        case let (.int(length1), .int(length2)):
            length1 == length2
        case (.address, .address):
            true
        case (.bool, .bool):
            true
        case let (.bytes(length1), .bytes(length2)):
            length1 == length2
        case (.function, .function):
            true
        case let (.array(type1, length1), .array(type2, length2)):
            type1 == type2 && length1 == length2
        case (.dynamicBytes, .dynamicBytes):
            true
        case (.string, .string):
            true
        default:
            false
        }
    }
}

extension ABI.Element.Function {
    public var signature: String {
        "\(name ?? "")(\(inputs.map { $0.type.abiRepresentation }.joined(separator: ",")))"
    }

    public var methodString: String {
        String(signature.sha3(.keccak256).prefix(8))
    }

    public var methodEncoding: Data {
        signature.data(using: .ascii)!.sha3(.keccak256)[0 ... 3]
    }
}

// MARK: - Event topic

extension ABI.Element.Event {
    public var signature: String {
        "\(name)(\(inputs.map { $0.type.abiRepresentation }.joined(separator: ",")))"
    }

    public var topic: Data {
        signature.data(using: .ascii)!.sha3(.keccak256)
    }
}

// MARK: - ABI.Element.ParameterType + ABIEncoding

extension ABI.Element.ParameterType: ABIEncoding {
    public var abiRepresentation: String {
        switch self {
        case let .uint(bits):
            return "uint\(bits)"

        case let .int(bits):
            return "int\(bits)"

        case .address:
            return "address"

        case .bool:
            return "bool"

        case let .bytes(length):
            return "bytes\(length)"

        case .dynamicBytes:
            return "bytes"

        case .function:
            return "function"

        case let .array(type: type, length: length):
            if length == 0 {
                return "\(type.abiRepresentation)[]"
            }
            return "\(type.abiRepresentation)[\(length)]"

        case let .tuple(types: types):
            let typesRepresentation = types.map { $0.abiRepresentation }
            let typesJoined = typesRepresentation.joined(separator: ",")
            return "tuple(\(typesJoined))"

        case .string:
            return "string"
        }
    }
}

// MARK: - ABI.Element.ParameterType + ABIValidation

extension ABI.Element.ParameterType: ABIValidation {
    public var isValid: Bool {
        switch self {
        case let .uint(bits),
             let .int(bits):
            return bits > 0 && bits <= 256 && bits % 8 == 0

        case let .bytes(length):
            return length > 0 && length <= 32

        case let .array(type: type, _):
            return type.isValid

        case let .tuple(types: types):
            for t in types {
                if !t.isValid {
                    return false
                }
            }
            return true

        default:
            return true
        }
    }
}
