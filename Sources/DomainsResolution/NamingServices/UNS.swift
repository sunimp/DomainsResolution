//
//  UNS.swift
//  DomainsResolution
//
//  Created by Sun on 2020/8/12.
//

import Foundation

// MARK: - UNS

class UNS: CommonNamingService, NamingService {
    // MARK: Nested Types

    typealias GeneralFunction<T> = () throws -> T

    // MARK: Static Properties

    static let name: NamingServiceName = .uns

    // MARK: Properties

    var layer1: UNSLayer!
    var layer2: UNSLayer!
    var znsLayer: ZNS!
    let asyncResolver: AsyncResolver

    // MARK: Lifecycle

    init(_ config: Configurations) throws {
        asyncResolver = AsyncResolver()
        super.init(
            name: Self.name,
            providerURL: config.uns.layer1.providerURL,
            networking: config.uns.layer1.networking
        )
        let layer1Contracts = try parseContractAddresses(config: config.uns.layer1)
        let layer2Contracts = try parseContractAddresses(config: config.uns.layer2)

        layer1 = try UNSLayer(name: .layer1, config: config.uns.layer1, contracts: layer1Contracts)
        layer2 = try UNSLayer(name: .layer2, config: config.uns.layer2, contracts: layer2Contracts)
        znsLayer = try ZNS(config.uns.znsLayer)
        
        guard layer1 != nil, layer2 != nil, znsLayer != nil else {
            throw ResolutionError.proxyReaderNonInitialized
        }
    }

    // MARK: Functions

    func isSupported(domain: String) -> Bool {
        layer2.isSupported(domain: domain)
    }
        
    func owner(domain: String) throws -> String {
        try asyncResolver.safeResolve(
            listOfFunc: [
                { try self.layer1.owner(domain: domain) },
                { try self.layer2.owner(domain: domain) },
                {
                    if self.znsLayer.isSupported(domain: domain) {
                        return try self.znsLayer.owner(domain: domain)
                    }
                    throw ResolutionError.unregisteredDomain
                },
            ]
        )
    }

    func record(domain: String, key: String) throws -> String {
        try asyncResolver.safeResolve(
            listOfFunc: [
                { try self.layer1.record(domain: domain, key: key) },
                { try self.layer2.record(domain: domain, key: key) },
                {
                    if self.znsLayer.isSupported(domain: domain) {
                        return try self.znsLayer.record(domain: domain, key: key)
                    }
                    throw ResolutionError.unregisteredDomain
                },
            ]
        )
    }

    func records(keys: [String], for domain: String) throws -> [String: String] {
        try asyncResolver.safeResolve(
            listOfFunc: [
                { try self.layer1.records(keys: keys, for: domain) },
                { try self.layer2.records(keys: keys, for: domain) },
                {
                    if self.znsLayer.isSupported(domain: domain) {
                        return try self.znsLayer.records(keys: keys, for: domain)
                    }
                    throw ResolutionError.unregisteredDomain
                },
            ]
        )
    }

    func allRecords(domain: String) throws -> [String: String] {
        try asyncResolver.safeResolve(
            listOfFunc: [
                { try self.layer1.allRecords(domain: domain) },
                { try self.layer2.allRecords(domain: domain) },
                {
                    if self.znsLayer.isSupported(domain: domain) {
                        return try self.znsLayer.allRecords(domain: domain)
                    }
                    throw ResolutionError.unregisteredDomain
                },
            ]
        )
    }

    func getTokenUri(tokenID: String) throws -> String {
        try asyncResolver.safeResolve(
            listOfFunc: [
                { try self.layer1.getTokenUri(tokenID: tokenID) },
                { try self.layer2.getTokenUri(tokenID: tokenID) },
            ]
        )
    }

    func getDomainName(tokenID: String) throws -> String {
        try asyncResolver.safeResolve(
            listOfFunc: [
                { try self.layer1.getDomainName(tokenID: tokenID) },
                { try self.layer2.getDomainName(tokenID: tokenID) },
            ]
        )
    }

    func addr(domain: String, ticker: String) throws -> String {
        try asyncResolver.safeResolve(
            listOfFunc: [
                { try self.layer1.addr(domain: domain, ticker: ticker) },
                { try self.layer2.addr(domain: domain, ticker: ticker) },
                {
                    if self.znsLayer.isSupported(domain: domain) {
                        return try self.znsLayer.addr(domain: domain, ticker: ticker)
                    }
                    throw ResolutionError.unregisteredDomain
                },
            ]
        )
    }

    func addr(domain: String, network: String, token: String) throws -> String {
        try asyncResolver.safeResolve(
            listOfFunc: [
                { try self.layer1.addr(domain: domain, network: network, token: token) },
                { try self.layer2.addr(domain: domain, network: network, token: token) },
                {
                    if self.znsLayer.isSupported(domain: domain) {
                        return try self.znsLayer.addr(domain: domain, network: network, token: token)
                    }
                    throw ResolutionError.unregisteredDomain
                },
            ]
        )
    }

    func resolver(domain: String) throws -> String {
        try asyncResolver.safeResolve(
            listOfFunc: [
                { try self.layer1.resolver(domain: domain) },
                { try self.layer2.resolver(domain: domain) },
                {
                    if self.znsLayer.isSupported(domain: domain) {
                        return try self.znsLayer.resolver(domain: domain)
                    }
                    throw ResolutionError.unregisteredDomain
                },
            ]
        )
    }

    func locations(domains: [String]) throws -> [String: Location] {
        let results = try asyncResolver.resolve(
            listOfFunc: [
                { try self.layer1.locations(domains: domains) },
                { try self.layer2.locations(domains: domains) },
            ]
        )
        
        try throwIfLayerHasError(results)

        var locations: [String: Location] = [:]
        let l2Response = Utillities.getLayerResult(from: results, for: .layer2)
        let l1Response = Utillities.getLayerResult(from: results, for: .layer1)

        for domain in domains {
            let l2Loc = l2Response[domain]!
            let l1Loc = l1Response[domain]!

            locations[domain] = l2Loc.owner == nil ? l1Loc : l2Loc
        }

        return locations
    }

    func batchOwners(domains: [String]) throws -> [String: String?] {
        let results = try asyncResolver.resolve(
            listOfFunc: [
                { try self.layer1.batchOwners(domains: domains) },
                { try self.layer2.batchOwners(domains: domains) },
            ]
        )
        
        var owners: [String: String?] = [:]
        try throwIfLayerHasError(results)
        
        let l2Result = Utillities.getLayerResult(from: results, for: .layer2)
        let l1Result = Utillities.getLayerResult(from: results, for: .layer1)
        
        for (domain, (l2owner, l1owner)) in zip(domains, zip(l2Result, l1Result)) {
            owners[domain] = l2owner == nil ? l1owner : l2owner
        }
        
        return owners
    }
    
    func reverseTokenID(address: String, location: UNSLocation?) throws -> String {
        let results = try asyncResolver.resolve(
            listOfFunc: [
                { try self.layer1.reverseTokenID(address: address) },
                { try self.layer2.reverseTokenID(address: address) },
            ]
        )
        
        if location != nil {
            let result = Utillities.getLayerResultWrapper(from: results, for: location!)
            if let err = result.1 {
                throw err
            }
            return result.0!
        }
        
        let l1Result = Utillities.getLayerResultWrapper(from: results, for: .layer1)

        if let l1error = l1Result.1 {
            if !Utillities.isResolutionError(expected: .reverseResolutionNotSpecified, error: l1error) {
                throw l1error
            }
        } else if let l1Value = l1Result.0 {
            return l1Value
        }
        
        let l2Result = Utillities.getLayerResultWrapper(from: results, for: .layer2)
        
        if let l2error = l2Result.1 {
            throw l2error
        }
        return l2Result.0!
    }

    private func parseContractAddresses(config: NamingServiceConfig) throws -> [UNSContract] {
        var contracts: [UNSContract] = []
        var proxyReaderContract: UNSContract?
        var unsContract: UNSContract?
        var cnsContract: UNSContract?

        let network = config.network.isEmpty
            ? try Self.getNetworkID(providerURL: config.providerURL, networking: config.networking)
            : config.network

        if let contractsContainer = try Self.parseContractAddresses(network: network) {
            unsContract = try getUNSContract(
                contracts: contractsContainer,
                type: .unsRegistry,
                providerURL: config.providerURL
            )
            cnsContract = try getUNSContract(
                contracts: contractsContainer,
                type: .cnsRegistry,
                providerURL: config.providerURL
            )
            proxyReaderContract = try getUNSContract(
                contracts: contractsContainer,
                type: .proxyReader,
                providerURL: config.providerURL
            )
        }

        if config.proxyReader != nil {
            let contract = try super.buildContract(
                address: config.proxyReader!,
                type: .proxyReader,
                providerURL: config.providerURL
            )
            proxyReaderContract = UNSContract(name: "ProxyReader", contract: contract, deploymentBlock: "earliest")
        }

        guard proxyReaderContract != nil else {
            throw ResolutionError.proxyReaderNonInitialized
        }
        contracts.append(proxyReaderContract!)
        if config.registryAddresses != nil, !config.registryAddresses!.isEmpty {
            try config.registryAddresses!.forEach {
                let contract = try super.buildContract(address: $0, type: .unsRegistry, providerURL: config.providerURL)
                contracts.append(UNSContract(name: "Registry", contract: contract, deploymentBlock: "earliest"))
            }
        }

        // if no registryAddresses has been provided to the config use the default ones
        if contracts.count == 1 {
            guard unsContract != nil else {
                throw ResolutionError.contractNotInitialized("UNSContract")
            }
            guard cnsContract != nil else {
                throw ResolutionError.contractNotInitialized("CNSContract")
            }
            contracts.append(unsContract!)
            contracts.append(cnsContract!)
        }

        return contracts
    }

    private func getUNSContract(
        contracts: [String: CommonNamingService.ContractAddressEntry],
        type: ContractType,
        providerURL: String
    ) throws
        -> UNSContract? {
        if let address = contracts[type.name]?.address {
            let contract = try super.buildContract(address: address, type: type, providerURL: providerURL)
            let deploymentBlock = contracts[type.name]?.deploymentBlock ?? "earliest"
            return UNSContract(name: type.name, contract: contract, deploymentBlock: deploymentBlock)
        }
        return nil
    }

    /// This is used only when all layers should not throw any errors. Methods like batchOwners or locations require
    /// both layers.
    private func throwIfLayerHasError<T>(_ results: [UNSLocation: AsyncConsumer<T>]) throws {
        let l2Results = Utillities.getLayerResultWrapper(from: results, for: .layer2)
        let l1Results = Utillities.getLayerResultWrapper(from: results, for: .layer1)
        let zResults = Utillities.getLayerResultWrapper(from: results, for: .znsLayer)

        guard l2Results.1 == nil else {
            throw l2Results.1!
        }

        guard l1Results.1 == nil else {
            throw l1Results.1!
        }
        
        guard zResults.1 == nil else {
            throw zResults.1!
        }
    }
}

extension Sequence where Element: Hashable {
    fileprivate func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}
