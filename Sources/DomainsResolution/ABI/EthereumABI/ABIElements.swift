//
//  ABIElements.swift
//  DomainsResolution
//
//  Created by Sun on 2021/2/16.
//

import BigInt
import Foundation

// swiftlint:disable nesting cyclomatic_complexity function_body_length
extension ABI {
    /// JSON Decoding
    public struct Input: Decodable {
        public var name: String?
        public var type: String
        public var indexed: Bool?
        public var components: [Input]?
    }

    public struct Output: Decodable {
        public var name: String?
        public var type: String
        public var components: [Output]?
    }

    public struct Record: Decodable {
        public var name: String?
        public var type: String?
        public var payable: Bool?
        public var constant: Bool?
        public var stateMutability: String?
        public var inputs: [ABI.Input]?
        public var outputs: [ABI.Output]?
        public var anonymous: Bool?
    }

    public enum Element {
        case function(Function)
        case constructor(Constructor)
        case fallback(Fallback)
        case event(Event)

        // MARK: Nested Types

        public enum ArraySize { // bytes for convenience
            case staticSize(UInt64)
            case dynamicSize
            case notArray
        }

        public enum StateMutability {
            case payable
            case mutating
            case view
            case pure

            // MARK: Computed Properties

            var isConstant: Bool {
                switch self {
                case .payable:
                    false
                case .mutating:
                    false
                default:
                    true
                }
            }

            var isPayable: Bool {
                switch self {
                case .payable:
                    true
                default:
                    false
                }
            }
        }

        public struct InOut {
            // MARK: Properties

            public let name: String
            public let type: ParameterType

            // MARK: Lifecycle

            public init(name: String, type: ParameterType) {
                self.name = name
                self.type = type
            }
        }

        public struct Function {
            // MARK: Properties

            public let name: String?
            public let inputs: [InOut]
            public let outputs: [InOut]
            public let stateMutability: StateMutability? = nil
            public let constant: Bool
            public let payable: Bool

            // MARK: Lifecycle

            public init(name: String?, inputs: [InOut], outputs: [InOut], constant: Bool, payable: Bool) {
                self.name = name
                self.inputs = inputs
                self.outputs = outputs
                self.constant = constant
                self.payable = payable
            }
        }

        public struct Constructor {
            // MARK: Properties

            public let inputs: [InOut]
            public let constant: Bool
            public let payable: Bool

            // MARK: Lifecycle

            public init(inputs: [InOut], constant: Bool, payable: Bool) {
                self.inputs = inputs
                self.constant = constant
                self.payable = payable
            }
        }

        public struct Fallback {
            // MARK: Properties

            public let constant: Bool
            public let payable: Bool

            // MARK: Lifecycle

            public init(constant: Bool, payable: Bool) {
                self.constant = constant
                self.payable = payable
            }
        }

        public struct Event {
            // MARK: Nested Types

            public struct Input {
                // MARK: Properties

                public let name: String
                public let type: ParameterType
                public let indexed: Bool

                // MARK: Lifecycle

                public init(name: String, type: ParameterType, indexed: Bool) {
                    self.name = name
                    self.type = type
                    self.indexed = indexed
                }
            }

            // MARK: Properties

            public let name: String
            public let inputs: [Input]
            public let anonymous: Bool

            // MARK: Lifecycle

            public init(name: String, inputs: [Input], anonymous: Bool) {
                self.name = name
                self.inputs = inputs
                self.anonymous = anonymous
            }
        }
    }
}

extension ABI.Element {
    public func encodeParameters(_ parameters: [AnyObject]) -> Data? {
        switch self {
        case let .constructor(constructor):
            guard parameters.count == constructor.inputs.count else {
                return nil
            }
            guard let data = ABIEncoder.encode(types: constructor.inputs, values: parameters) else {
                return nil
            }
            return data

        case .event:
            return nil

        case .fallback:
            return nil

        case let .function(function):
            guard parameters.count == function.inputs.count else {
                return nil
            }
            let signature = function.methodEncoding
            guard let data = ABIEncoder.encode(types: function.inputs, values: parameters) else {
                return nil
            }
            return signature + data
        }
    }
}

extension ABI.Element {
    public func decodeReturnData(_ data: Data) -> [String: Any]? {
        switch self {
        case .constructor:
            return nil
        case .event:
            return nil
        case .fallback:
            return nil
        case let .function(function):
            if data.isEmpty, function.outputs.count == 1 {
                let name = "0"
                let value = function.outputs[0].type.emptyValue
                var returnArray = [String: Any]()
                returnArray[name] = value
                if function.outputs[0].name != "" {
                    returnArray[function.outputs[0].name] = value
                }
                return returnArray
            }

            guard function.outputs.count * 32 <= data.count else {
                return nil
            }
            var returnArray = [String: Any]()
            var i = 0
            guard let values = ABIDecoder.decode(types: function.outputs, data: data) else {
                return nil
            }
            for output in function.outputs {
                let name = "\(i)"
                returnArray[name] = values[i]
                if output.name != "" {
                    returnArray[output.name] = values[i]
                }
                i += 1
            }
            return returnArray
        }
    }

    public func decodeInputData(_ rawData: Data) -> [String: Any]? {
        var data = rawData
        var sig: Data?
        switch rawData.count % 32 {
        case 0:
            break

        case 4:
            sig = rawData[0 ..< 4]
            data = Data(rawData[4 ..< rawData.count])

        default:
            return nil
        }
        switch self {
        case let .constructor(function):
            if data.isEmpty, function.inputs.count == 1 {
                let name = "0"
                let value = function.inputs[0].type.emptyValue
                var returnArray = [String: Any]()
                returnArray[name] = value
                if function.inputs[0].name != "" {
                    returnArray[function.inputs[0].name] = value
                }
                return returnArray
            }

            guard function.inputs.count * 32 <= data.count else {
                return nil
            }
            var returnArray = [String: Any]()
            var i = 0
            guard let values = ABIDecoder.decode(types: function.inputs, data: data) else {
                return nil
            }
            for input in function.inputs {
                let name = "\(i)"
                returnArray[name] = values[i]
                if input.name != "" {
                    returnArray[input.name] = values[i]
                }
                i += 1
            }
            return returnArray

        case .event:
            return nil

        case .fallback:
            return nil

        case let .function(function):
            if sig != nil, sig != function.methodEncoding {
                return nil
            }
            if data.isEmpty, function.inputs.count == 1 {
                let name = "0"
                let value = function.inputs[0].type.emptyValue
                var returnArray = [String: Any]()
                returnArray[name] = value
                if function.inputs[0].name != "" {
                    returnArray[function.inputs[0].name] = value
                }
                return returnArray
            }

            guard function.inputs.count * 32 <= data.count else {
                return nil
            }
            var returnArray = [String: Any]()
            var i = 0
            guard let values = ABIDecoder.decode(types: function.inputs, data: data) else {
                return nil
            }
            for input in function.inputs {
                let name = "\(i)"
                returnArray[name] = values[i]
                if input.name != "" {
                    returnArray[input.name] = values[i]
                }
                i += 1
            }
            return returnArray
        }
    }
}
