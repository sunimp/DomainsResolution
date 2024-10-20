//
//  ABIDecoder.swift
//  DomainsResolution
//
//  Created by Sun on 2021/2/16.
//

import BigInt
import Foundation

// MARK: - ABIDecoder

public struct ABIDecoder { }

// swiftlint:disable cyclomatic_complexity function_body_length
extension ABIDecoder {
    public static func decode(types: [ABI.Element.InOut], data: Data) -> [AnyObject]? {
        let params = types.compactMap { el -> ABI.Element.ParameterType in
            return el.type
        }
        return decode(types: params, data: data)
    }

    public static func decode(types: [ABI.Element.ParameterType], data: Data) -> [AnyObject]? {
        var toReturn = [AnyObject]()
        var consumed: UInt64 = 0
        for i in 0 ..< types.count {
            let (v, c) = decodeSingleType(type: types[i], data: data, pointer: consumed)
            guard let valueUnwrapped = v, let consumedUnwrapped = c else {
                return nil
            }
            toReturn.append(valueUnwrapped)
            consumed += consumedUnwrapped
        }
        guard toReturn.count == types.count else {
            return nil
        }
        return toReturn
    }

    public static func decodeSingleType(
        type: ABI.Element.ParameterType,
        data: Data,
        pointer: UInt64 = 0
    )
        -> (value: AnyObject?, bytesConsumed: UInt64?) {
        let (elData, nextPtr) = followTheData(type: type, data: data, pointer: pointer)
        guard let elementItself = elData, let nextElementPointer = nextPtr else {
            return (nil, nil)
        }
        switch type {
        case let .uint(bits):
            guard elementItself.count >= 32 else {
                break
            }
            let mod = BigUInt(1) << bits
            let dataSlice = elementItself[0 ..< 32]
            let v = BigUInt(dataSlice) % mod
            return (v as AnyObject, type.memoryUsage)

        case let .int(bits):
            guard elementItself.count >= 32 else {
                break
            }
            let mod = BigInt(1) << bits
            let dataSlice = elementItself[0 ..< 32]
            let v = BigInt.fromTwosComplement(data: dataSlice) % mod
            return (v as AnyObject, type.memoryUsage)

        case .address:
            guard elementItself.count >= 32 else {
                break
            }
            let dataSlice = elementItself[12 ..< 32]
            let address = EthereumAddress(dataSlice)
            return (address as AnyObject, type.memoryUsage)

        case .bool:
            guard elementItself.count >= 32 else {
                break
            }
            let dataSlice = elementItself[0 ..< 32]
            let v = BigUInt(dataSlice)
            if v == BigUInt(1) {
                return (true as AnyObject, type.memoryUsage)
            } else if v == BigUInt(0) {
                return (false as AnyObject, type.memoryUsage)
            }

        case let .bytes(length):
            guard elementItself.count >= 32 else {
                break
            }
            let dataSlice = elementItself[0 ..< length]
            return (dataSlice as AnyObject, type.memoryUsage)

        case .string:
            guard elementItself.count >= 32 else {
                break
            }
            var dataSlice = elementItself[0 ..< 32]
            let length = UInt64(BigUInt(dataSlice))
            guard elementItself.count >= 32 + length else {
                break
            }
            dataSlice = elementItself[32 ..< 32 + length]
            guard let string = String(data: dataSlice, encoding: .utf8) else {
                break
            }

            return (string as AnyObject, type.memoryUsage)

        case .dynamicBytes:

            guard elementItself.count >= 32 else {
                break
            }
            var dataSlice = elementItself[0 ..< 32]
            let length = UInt64(BigUInt(dataSlice))
            guard elementItself.count >= 32 + length else {
                break
            }
            dataSlice = elementItself[32 ..< 32 + length]

            return (dataSlice as AnyObject, type.memoryUsage)

        case let .array(type: subType, length: length):
            switch type.arraySize {
            case .dynamicSize:

                if subType.isStatic {
                    guard elementItself.count >= 32 else {
                        break
                    }
                    var dataSlice = elementItself[0 ..< 32]
                    let length = UInt64(BigUInt(dataSlice))
                    guard elementItself.count >= 32 + subType.memoryUsage * length else {
                        break
                    }
                    dataSlice = elementItself[32 ..< 32 + subType.memoryUsage * length]
                    var subpointer: UInt64 = 32
                    var toReturn = [AnyObject]()
                    for _ in 0 ..< length {
                        let (v, c) = decodeSingleType(type: subType, data: elementItself, pointer: subpointer)
                        guard let valueUnwrapped = v, let consumedUnwrapped = c else {
                            break
                        }
                        toReturn.append(valueUnwrapped)
                        subpointer += consumedUnwrapped
                    }
                    return (toReturn as AnyObject, type.memoryUsage)
                } else {
                    guard elementItself.count >= 32 else {
                        break
                    }
                    var dataSlice = elementItself[0 ..< 32]
                    let length = UInt64(BigUInt(dataSlice))
                    guard elementItself.count >= 32 else {
                        break
                    }
                    dataSlice = Data(elementItself[32 ..< elementItself.count])
                    var subpointer: UInt64 = 0
                    var toReturn = [AnyObject]()

                    for _ in 0 ..< length {
                        let (v, c) = decodeSingleType(type: subType, data: dataSlice, pointer: subpointer)
                        guard let valueUnwrapped = v, let consumedUnwrapped = c else {
                            break
                        }
                        toReturn.append(valueUnwrapped)
                        subpointer += consumedUnwrapped
                    }
                    return (toReturn as AnyObject, nextElementPointer)
                }

            case let .staticSize(staticLength):

                guard length == staticLength else {
                    break
                }
                var toReturn = [AnyObject]()
                var consumed: UInt64 = 0
                for _ in 0 ..< length {
                    let (v, c) = decodeSingleType(type: subType, data: elementItself, pointer: consumed)
                    guard let valueUnwrapped = v, let consumedUnwrapped = c else {
                        return (nil, nil)
                    }
                    toReturn.append(valueUnwrapped)
                    consumed += consumedUnwrapped
                }
                if subType.isStatic {
                    return (toReturn as AnyObject, consumed)
                } else {
                    return (toReturn as AnyObject, nextElementPointer)
                }

            case .notArray:
                break
            }

        case let .tuple(types: subTypes):

            var toReturn = [AnyObject]()
            var consumed: UInt64 = 0
            for i in 0 ..< subTypes.count {
                let (v, c) = decodeSingleType(type: subTypes[i], data: elementItself, pointer: consumed)
                guard let valueUnwrapped = v, let consumedUnwrapped = c else {
                    return (nil, nil)
                }
                toReturn.append(valueUnwrapped)
                consumed += consumedUnwrapped
            }

            if type.isStatic {
                return (toReturn as AnyObject, consumed)
            } else {
                return (toReturn as AnyObject, nextElementPointer)
            }

        case .function:

            guard elementItself.count >= 32 else {
                break
            }
            let dataSlice = elementItself[8 ..< 32]

            return (dataSlice as AnyObject, type.memoryUsage)
        }
        return (nil, nil)
    }

    fileprivate static func followTheData(
        type: ABI.Element.ParameterType,
        data: Data,
        pointer: UInt64 = 0
    )
        -> (elementEncoding: Data?, nextElementPointer: UInt64?) {
        if type.isStatic {
            guard data.count >= pointer + type.memoryUsage else {
                return (nil, nil)
            }
            let elementItself = data[pointer ..< pointer + type.memoryUsage]
            let nextElement = pointer + type.memoryUsage

            return (Data(elementItself), nextElement)
        } else {
            guard data.count >= pointer + type.memoryUsage else {
                return (nil, nil)
            }
            let dataSlice = data[pointer ..< pointer + type.memoryUsage]
            let bn = BigUInt(dataSlice)
            if bn > UINT64_MAX || bn >= data.count {
                // there are ERC20 contracts that use bytes32 intead of string. Let's be optimistic and return some data
                if case .string = type {
                    let nextElement = pointer + type.memoryUsage
                    let preambula = BigUInt(32).abiEncode(bits: 256)!
                    return (preambula + Data(dataSlice), nextElement)
                } else if case .dynamicBytes = type {
                    let nextElement = pointer + type.memoryUsage
                    let preambula = BigUInt(32).abiEncode(bits: 256)!
                    return (preambula + Data(dataSlice), nextElement)
                }
                return (nil, nil)
            }
            let elementPointer = UInt64(bn)
            let elementItself = data[elementPointer ..< UInt64(data.count)]
            let nextElement = pointer + type.memoryUsage

            return (Data(elementItself), nextElement)
        }
    }
}
