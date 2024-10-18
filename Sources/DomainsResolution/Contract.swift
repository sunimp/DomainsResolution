//
//  Contract.swift
//  DomainsResolution
//
//  Created by Sun on 2020/8/13.
//

// MARK: - IdentifiableResult

struct IdentifiableResult<T> {
    var id: String
    var result: T
}

// MARK: - MultiCallData

struct MultiCallData {
    let methodName: String
    let args: [Any]
}

import Foundation

// MARK: - Contract

class Contract {
    // MARK: Static Properties

    static let ownersKey = "owners"
    static let resolversKey = "resolvers"
    static let valuesKey = "values"
    static let multiCallMethodName = "multicall"

    // MARK: Properties

    let batchIDOffset = 128

    let address: String
    let providerURL: String
    let coder: ABICoder
    let networking: NetworkingLayer

    // MARK: Lifecycle

    init(providerURL: String, address: String, abi: ABIContract, networking: NetworkingLayer) {
        self.address = address
        self.providerURL = providerURL
        coder = ABICoder(abi)
        self.networking = networking
    }

    // MARK: Functions

    func multiCall(calls: [MultiCallData]) throws -> [Data] {
        let encodedCalls = try calls.map { try self.coder.encode(method: $0.methodName, args: $0.args) }
        let encodedMultiCall = try coder.encode(method: Self.multiCallMethodName, args: [encodedCalls])
        let body = JsonRpcPayload(id: "1", data: encodedMultiCall, to: address)
        let response = try postRequestForString(body)!
        let decodedResponse = try coder.decode(response, from: Self.multiCallMethodName) as? [String: Any]
        guard
            let decoded = decodedResponse,
            let decodedResults = decoded["results"] as? [Data]
        else {
            throw ABICoderError.couldNotDecode(method: Self.multiCallMethodName, value: response)
        }
        return decodedResults
    }

    func callMethod(methodName: String, args: [Any]) throws -> Any {
        let encodedData = try coder.encode(method: methodName, args: args)
        let body = JsonRpcPayload(id: "1", data: encodedData, to: address)
        let response = try postRequestForString(body)!
        return try coder.decode(response, from: methodName)
    }

    func callBatchMethod(methodName: String, argsArray: [[Any]]) throws -> [IdentifiableResult<Any?>] {
        let encodedDataArray = try argsArray.map { try self.coder.encode(method: methodName, args: $0) }
        let bodyArray: [JsonRpcPayload] = encodedDataArray.enumerated()
            .map { JsonRpcPayload(
                id: String($0.offset + batchIDOffset),
                data: $0.element,
                to: address
            ) }
        let response = try postBatchRequest(bodyArray)
        return try response.map {
            guard let responseElement = $0 else {
                throw ResolutionError.recordNotSupported
            }

            var res: Any?
            do {
                res = try self.coder.decode(responseElement.result, from: methodName)
            } catch ABICoderError.couldNotDecode {
                res = nil
            }
            return IdentifiableResult<Any?>(id: responseElement.id, result: res)
        }
    }

    private func postRequestForString(_ body: JsonRpcPayload) throws -> String? {
        let postResponse = try postRequest(body)
        switch postResponse {
        case let .string(result):
            return result
        default:
            return nil
        }
    }

    private func postRequest(_ body: JsonRpcPayload) throws -> ParamElement? {
        let postRequest = APIRequest(providerURL, networking: networking)
        var resp: JsonRpcResponseArray?
        var err: Error?
        let semaphore = DispatchSemaphore(value: 0)
        try postRequest.post(body, completion: { result in
            switch result {
            case let .success(response):
                resp = response
            case let .failure(error):
                err = error
            }
            semaphore.signal()
        })
        semaphore.wait()
        guard err == nil else {
            throw err!
        }
        return resp?[0].result
    }

    private func postBatchRequest(_ bodyArray: [JsonRpcPayload]) throws -> [IdentifiableResult<String>?] {
        let postRequest = APIRequest(providerURL, networking: networking)
        var resp: JsonRpcResponseArray?
        var err: Error?
        let semaphore = DispatchSemaphore(value: 0)
        try postRequest.post(bodyArray, completion: { result in
            switch result {
            case let .success(response):
                resp = response
            case let .failure(error):
                err = error
            }
            semaphore.signal()
        })
        semaphore.wait()
        guard err == nil else {
            throw err!
        }

        guard let responseArray = resp else {
            throw APIError.decodingError
        }

        return responseArray.map {
            if case let ParamElement.string(stringResult) = $0.result {
                return IdentifiableResult<String>(id: $0.id, result: stringResult)
            }
            return nil
        }
    }

    private func stringParamElementToData(_ param: ParamElement?) throws -> Data {
        guard case let .string(paramString) = param else {
            throw ResolutionError.badRequestOrResponse
        }
        return Data(hex: paramString)
    }
}
