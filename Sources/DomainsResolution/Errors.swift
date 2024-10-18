//
//  Errors.swift
//  DomainsResolution
//
//  Created by Sun on 2020/8/12.
//

import Foundation

// MARK: - ResolutionError

public enum ResolutionError: Error {
    case unregisteredDomain
    case unsupportedDomain
    case recordNotFound(String)
    case recordNotSupported
    case unsupportedNetwork
    case unspecifiedResolver(String)
    case unknownError(Error)
    case proxyReaderNonInitialized
    case registryAddressIsNotProvided
    case inconsistentDomainArray
    case methodNotSupported
    case tooManyResponses
    case executionReverted
    case badRequestOrResponse
    case unsupportedServiceName
    case invalidDomainName
    case contractNotInitialized(String)
    case reverseResolutionNotSpecified
    case unauthenticatedRequest
    case requestBeingRateLimited

    // MARK: Static Properties

    static let tooManyResponsesCode = -32005
    static let badRequestOrResponseCode = -32042

    // MARK: Static Functions

    static func parse(errorResponse: NetworkErrorResponse) -> ResolutionError? {
        let error = errorResponse.error

        if error.message.starts(with: "execution reverted") {
            return .executionReverted
        }

        switch error.code {
        case tooManyResponsesCode:
            return .tooManyResponses
        case badRequestOrResponseCode:
            return .badRequestOrResponse
        default:
            return nil
        }
    }
}

// MARK: - NetworkErrorResponse

struct NetworkErrorResponse: Decodable {
    var jsonrpc: String
    var id: String
    var error: ErrorID
}

// MARK: - ErrorID

struct ErrorID: Codable {
    var code: Int
    var message: String
    var data: String?
}
