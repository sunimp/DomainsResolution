//
//  ABICoder.swift
//  DomainsResolution
//
//  Created by Sun on 2020/8/18.
//

import Foundation

typealias ABIContract = [ABI.Element]

// MARK: - ABICoderError

enum ABICoderError: Error {
    case wrongABIInterfaceForMethod(method: String)
    case couldNotEncode(method: String, args: [Any])
    case couldNotDecode(method: String, value: String)
}

// MARK: - ABICoder

// swiftlint:disable identifier_name
class ABICoder {
    // MARK: Properties

    let abi: ABIContract

    // MARK: Computed Properties

    private var methods: [String: ABI.Element] {
        var toReturn = [String: ABI.Element]()
        for m in abi {
            switch m {
            case let .function(function):
                guard let name = function.name else {
                    continue
                }
                toReturn[name] = m

            default:
                continue
            }
        }
        return toReturn
    }

    // MARK: Lifecycle

    init(_ abi: ABIContract) {
        self.abi = abi
    }

    // MARK: Functions

    // MARK: - Decode Block

    public func decode(_ data: String, from method: String) throws -> Any {
        if method == "fallback" {
            return [String: Any]()
        }

        guard let function = methods[method] else {
            throw ABICoderError.wrongABIInterfaceForMethod(method: method)
        }
        guard case .function = function else {
            throw ABICoderError.wrongABIInterfaceForMethod(method: method)
        }
        guard let decoded = function.decodeReturnData(Data(hex: data)) else {
            throw ABICoderError.couldNotDecode(method: method, value: data)
        }

        return decoded
    }

    // MARK: - Encode Block

    public func encode(method: String, args: [Any]) throws -> String {
        let argsObjects = args.map { $0 as AnyObject }

        let foundMethod = methods.filter { key, _ -> Bool in
            return key == method
        }
        guard foundMethod.count == 1 else {
            throw ABICoderError.wrongABIInterfaceForMethod(method: method)
        }

        let abiMethod = foundMethod[method]
        guard let encodedData = abiMethod?.encodeParameters(argsObjects) else {
            throw ABICoderError.couldNotEncode(method: method, args: args)
        }

        return encodedData.toHexString().addHexPrefix()
    }
}
