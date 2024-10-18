//
//  ZNS.swift
//  DomainsResolution
//
//  Created by Sun on 2020/9/18.
//

import Foundation

class ZNS: CommonNamingService, NamingService {
    // MARK: Properties

    var network: String

    let registryAddress: String
    let registryMap: [String: String] = [
        "mainnet": "0x9611c53be6d1b32058b2747bdececed7e1216793",
        "testnet": "0xB925adD1d5EaF13f40efD43451bF97A22aB3d727",
    ]

    // MARK: Lifecycle

    init(_ config: NamingServiceConfig) throws {
        network = config.network

        var registryAddress: String? = registryMap[network]
        if config.registryAddresses != nil, !config.registryAddresses!.isEmpty {
            registryAddress = config.registryAddresses![0]
        }

        guard registryAddress != nil else {
            throw ResolutionError.registryAddressIsNotProvided
        }
        self.registryAddress = registryAddress!
        super.init(name: .zns, providerURL: config.providerURL, networking: config.networking)
    }

    // MARK: Overridden Functions

    // MARK: - CommonNamingService

    override func childHash(parent: [UInt8], label: [UInt8]) -> [UInt8] {
        (parent + label.sha2(.sha256)).sha2(.sha256)
    }

    // MARK: Functions

    func isSupported(domain: String) -> Bool {
        domain.hasSuffix(".zil")
    }

    func owner(domain: String) throws -> String {
        let recordAddresses = try recordsAddresses(domain: domain)
        let (ownerAddress, _) = recordAddresses
        guard Utillities.isNotEmpty(ownerAddress) else {
            throw ResolutionError.unregisteredDomain
        }

        return ownerAddress
    }

    func batchOwners(domains _: [String]) throws -> [String: String?] {
        throw ResolutionError.methodNotSupported
    }

    func addr(domain: String, ticker: String) throws -> String {
        let key = "crypto.\(ticker.uppercased()).address"
        return try record(domain: domain, key: key)
    }

    func addr(domain _: String, network _: String, token _: String) throws -> String {
        throw ResolutionError.methodNotSupported
    }

    func record(domain: String, key: String) throws -> String {
        let records = try records(keys: [key], for: domain)

        guard
            let record = records[key]
        else {
            throw ResolutionError.recordNotFound(name.rawValue)
        }

        return record
    }

    func records(keys: [String], for domain: String) throws -> [String: String] {
        guard let records = try records(address: resolver(domain: domain), keys: []) as? [String: String] else {
            throw ResolutionError.recordNotFound(name.rawValue)
        }
        return records.filter { keys.contains($0.key) }
    }

    func allRecords(domain: String) throws -> [String: String] {
        guard let records = try records(address: resolver(domain: domain), keys: []) as? [String: String] else {
            throw ResolutionError.recordNotFound(name.rawValue)
        }
        return records
    }

    func getTokenUri(tokenID _: String) throws -> String {
        throw ResolutionError.methodNotSupported
    }

    func getDomainName(tokenID _: String) throws -> String {
        throw ResolutionError.methodNotSupported
    }

    func locations(domains _: [String]) throws -> [String: Location] {
        throw ResolutionError.methodNotSupported
    }

    // MARK: - get Resolver

    func resolver(domain: String) throws -> String {
        let recordAddresses = try recordsAddresses(domain: domain)
        let (_, resolverAddress) = recordAddresses
        guard Utillities.isNotEmpty(resolverAddress) else {
            throw ResolutionError.unspecifiedResolver(name.rawValue)
        }

        return resolverAddress
    }

    func buildContract(address: String) -> ContractZNS {
        ContractZNS(
            providerURL: providerURL,
            address: address.replacingOccurrences(of: "0x", with: ""),
            networking: networking
        )
    }

    // MARK: - Helper functions

    private func recordsAddresses(domain: String) throws -> (String, String) {
        if !isSupported(domain: domain) {
            throw ResolutionError.unsupportedDomain
        }

        let namehash = namehash(domain: domain)
        let records = try records(address: registryAddress, keys: [namehash])

        guard
            let record = records[namehash] as? [String: Any],
            let arguments = record["arguments"] as? [Any], arguments.count == 2,
            let ownerAddress = arguments[0] as? String, let resolverAddress = arguments[1] as? String
        else {
            throw ResolutionError.unregisteredDomain
        }

        return (ownerAddress, resolverAddress)
    }

    private func records(address: String, keys: [String] = []) throws -> [String: Any] {
        let resolverContract: ContractZNS = buildContract(address: address)

        guard
            let records = try resolverContract.fetchSubState(
                field: "records",
                keys: keys
            ) as? [String: Any]
        else {
            throw ResolutionError.unspecifiedResolver(name.rawValue)
        }

        return records
    }
}
