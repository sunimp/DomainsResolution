//
//  JSON_RPC.swift
//  DomainsResolution
//
//  Created by Sun on 2020/8/20.
//

import Foundation

// MARK: - JsonRpcPayload

public struct JsonRpcPayload: Codable {
    // MARK: Nested Types

    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case method
        case params
    }

    // MARK: Properties

    let jsonrpc, id, method: String
    let params: [ParamElement]

    // MARK: Lifecycle

    init(jsonrpc: String, id: String, method: String, params: [ParamElement]) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
    }

    init(id: String, data: String, to address: String) {
        self.init(
            jsonrpc: "2.0",
            id: id,
            method: "eth_call",
            params: [
                ParamElement.paramClass(ParamClass(data: data, to: address)),
                ParamElement.string("latest"),
            ]
        )
    }
}

// MARK: - ParamElement

public enum ParamElement: Codable {
    case paramClass(ParamClass)
    case string(String)
    case array([ParamElement])
    case dictionary([String: ParamElement])

    // MARK: Lifecycle

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let elem = try? container.decode(String.self) {
            self = .string(elem)
            return
        }
        if let elem = try? container.decode(ParamClass.self) {
            self = .paramClass(elem)
            return
        }
        if let elem = try? container.decode([ParamElement].self) {
            self = .array(elem)
            return
        }
        if let elem = try? container.decode([String: ParamElement].self) {
            self = .dictionary(elem)
            return
        }

        throw DecodingError.typeMismatch(
            ParamElement.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Wrong type for ParamElement"
            )
        )
    }

    // MARK: Functions

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .paramClass(elem):
            try container.encode(elem)
        case let .string(elem):
            try container.encode(elem)
        case let .array(array):
            try container.encode(array)
        case let .dictionary(dict):
            try container.encode(dict)
        }
    }
}

// MARK: - ParamClass

public struct ParamClass: Codable {
    let data: String
    let to: String
}

// MARK: - JsonRpcResponse

public struct JsonRpcResponse: Decodable {
    // MARK: Nested Types

    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case result
    }

    // MARK: Properties

    let jsonrpc: String
    let id: String
    let result: ParamElement
}
