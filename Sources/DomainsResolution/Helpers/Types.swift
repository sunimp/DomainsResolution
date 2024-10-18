//
//  Types.swift
//  DomainsResolution
//
//  Created by Sun on 2020/9/18.
//

import Foundation

public typealias StringResultConsumer = (Result<String, ResolutionError>) -> Void
public typealias StringsArrayResultConsumer = (Result<[String?], ResolutionError>) -> Void
public typealias DictionaryResultConsumer = (Result<[String: String], ResolutionError>) -> Void
public typealias DictionaryOptionalResultConsumer = (Result<[String: String?], ResolutionError>) -> Void
public typealias DictionaryLocationResultConsumer = (Result<[String: Location], ResolutionError>) -> Void
public typealias DnsRecordsResultConsumer = (Result<[DnsRecord], Error>) -> Void
public typealias TokenUriMetadataResultConsumer = (Result<TokenUriMetadata, ResolutionError>) -> Void
public typealias BoolResultConsumer = (Result<Bool, Error>) -> Void

typealias AsyncConsumer<T> = (T?, Error?)

// MARK: - NamingServiceName

public enum NamingServiceName: String {
    case uns
    case zns
}

// MARK: - UNSLocation

public enum UNSLocation: String {
    case layer1
    case layer2
    case znsLayer
}

// MARK: - UNSContract

public struct UNSContract {
    let name: String
    let contract: Contract
    let deploymentBlock: String
}

// MARK: - Location

public struct Location: Equatable {
    var registryAddress: String?
    var resolverAddress: String?
    var networkID: String?
    var blockchain: String?
    var owner: String?
    var providerURL: String?
}

public let ethCoinIndex = 60
