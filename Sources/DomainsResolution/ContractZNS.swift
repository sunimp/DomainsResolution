//
//  ContractZNS.swift
//  DomainsResolution
//
//  Created by Sun on 2020/9/18.
//

import Foundation

class ContractZNS {
    // MARK: Properties

    let address: String
    let providerURL: String
    let networking: NetworkingLayer

    // MARK: Lifecycle

    init(providerURL: String, address: String, networking: NetworkingLayer) {
        self.address = address
        self.providerURL = providerURL
        self.networking = networking
    }

    // MARK: Functions

    func fetchSubState(field: String, keys: [String]) throws -> Any {
        let body = JsonRpcPayload(
            jsonrpc: "2.0",
            id: "1",
            method: "GetSmartContractSubState",
            params: [
                ParamElement.string(address),
                ParamElement.string(field),
                ParamElement.array(keys.map { ParamElement.string($0) }),
            ]
        )
        do {
            let response = try postRequest(body)!

            guard
                case let ParamElement.dictionary(dict) = response,
                let results = reduce(dict: dict)[field] as? [String: Any]
            else {
                print("Invalid response, can't process")
                return response
            }

            return results
            // Zilliqa returns null if the domain is not registered,
            // this causes our decoder to fail and throw APIError.decodingError
        } catch APIError.decodingError {
            throw ResolutionError.unregisteredDomain
        }
    }

    private func postRequest(_ body: JsonRpcPayload) throws -> Any? {
        let postRequest = APIRequest(providerURL, networking: networking)
        var resp: JsonRpcResponse?
        var err: Error?
        let semaphore = DispatchSemaphore(value: 0)
        try postRequest.post(body, completion: { result in
            switch result {
            case let .success(response):
                resp = response[0]
            case let .failure(error):
                err = error
            }
            semaphore.signal()
        })
        semaphore.wait()
        guard err == nil else {
            throw err!
        }
        return resp?.result
    }

    // MARK: - PRIVATE Helper functions

    private func reduce(dict: [String: ParamElement]) -> [String: Any] {
        dict.reduce(into: [String: Any]()) { dict, pair in
            let (key, value) = pair

            switch value {
            case let .paramClass(elem):
                dict[key] = elem
            case let .string(elem):
                dict[key] = elem
            case let .array(array):
                dict[key] = self.map(array: array)
            case let .dictionary(dictionary):
                dict[key] = self.reduce(dict: dictionary)
            }
        }
    }

    private func map(array: [ParamElement]) -> [Any] {
        array.map { value -> Any in
            switch value {
            case let .paramClass(elem):
                return elem
            case let .string(elem):
                return elem
            case let .array(array):
                return self.map(array: array)
            case let .dictionary(dictionary):
                return self.reduce(dict: dictionary)
            }
        }
    }
}
