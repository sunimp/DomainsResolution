//
//  UNSLayer.swift
//  DomainsResolution
//
//  Created by Sun on 2020/8/12.
//

import BigInt
import Foundation

// MARK: - UNSLayer

class UNSLayer: CommonNamingService {
    // MARK: Nested Types

    struct OwnerResolverRecord {
        let owner: String
        let resolver: String
        let record: String
    }

    // MARK: Static Properties

    static let TransferEventSignature = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    static let NewURIEventSignature = "0xc5beef08f693b11c316c0c8394a377a0033c9cf701b8cd8afd79cecef60c3952"
    static let getDataForManyMethodName = "getDataForMany"
    static let reverseOfMethodName = "reverseOf"
    static let getAddressMethodName = "getAddress"
    static let tokenURIMethodName = "tokenURI"
    static let registryOfMethodName = "registryOf"
    static let existName = "exists"

    // MARK: Properties

    let network: String
    let blockchain: String?
    let layer: UNSLocation
    var nsRegistries: [UNSContract]
    var proxyReaderContract: Contract?

    // MARK: Lifecycle

    init(name: UNSLocation, config: NamingServiceConfig, contracts: [UNSContract]) throws {
        network = config.network.isEmpty
            ? try Self.getNetworkName(providerURL: config.providerURL, networking: config.networking)
            : config.network
        blockchain = Self.networkToBlockchain[network]
        nsRegistries = []
        layer = name
        super.init(name: .uns, providerURL: config.providerURL, networking: config.networking)
        for item in contracts {
            if item.name == "ProxyReader" {
                proxyReaderContract = item.contract
            } else {
                nsRegistries.append(item)
            }
        }
    }

    // MARK: Functions

    func isSupported(domain: String) -> Bool {
        if domain ~= "^[^-]*[^-]*\\.(eth|luxe|xyz|kred|addr\\.reverse)$" {
            return false
        }
        let split = domain.split(separator: ".")
        let tld = split.suffix(1).joined(separator: "")
        if tld == "zil" {
            return false
        }
        let tokenID = namehash(domain: tld)
        if let response = try? proxyReaderContract?.callMethod(methodName: Self.existName, args: [tokenID]) {
            guard
                let result = response as? [String: Bool],
                let isExist = result["0"]
            else {
                return false
            }
            return isExist
        }
        return false
    }

    // MARK: - geters of Owner and Resolver

    func owner(domain: String) throws -> String {
        let tokenID = super.namehash(domain: domain)
        let res: Any
        do {
            res = try getDataForMany(keys: [Contract.ownersKey], for: [tokenID])
        } catch {
            if error is ABICoderError {
                throw ResolutionError.unregisteredDomain
            }
            throw error
        }
        guard
            let rec = unfoldForMany(contractResult: res, key: Contract.ownersKey),
            !rec.isEmpty
        else {
            throw ResolutionError.unregisteredDomain
        }

        guard Utillities.isNotEmpty(rec[0]) else {
            throw ResolutionError.unregisteredDomain
        }
        return rec[0]
    }

    func batchOwners(domains: [String]) throws -> [String?] {
        let tokenIDs = domains.map { super.namehash(domain: $0) }
        let res: Any
        do {
            res = try getDataForMany(keys: [Contract.ownersKey], for: tokenIDs)
        } catch {
            throw error
        }
        guard
            let data = res as? [String: Any],
            let ownersFolded = data["1"] as? [Any]
        else {
            return []
        }
        return ownersFolded.map { let address = unfoldAddress($0)
            return Utillities.isNotEmpty(address) ? address : nil
        }
    }

    func resolver(domain: String) throws -> String {
        let tokenID = super.namehash(domain: domain)
        return try resolverFromTokenID(tokenID: tokenID)
    }

    func addr(domain: String, ticker: String) throws -> String {
        let key = "crypto.\(ticker.uppercased()).address"
        return try record(domain: domain, key: key)
    }

    func addr(domain: String, network: String, token: String) throws -> String {
        let tokenID = super.namehash(domain: domain)
        let ownerRes: Any
        do {
            ownerRes = try getDataForMany(keys: [Contract.resolversKey, Contract.ownersKey], for: [tokenID])
            guard
                let owners = unfoldForMany(contractResult: ownerRes, key: Contract.ownersKey),
                Utillities.isNotEmpty(owners[0])
            else {
                throw ResolutionError.unregisteredDomain
            }
        } catch {
            if error is ABICoderError {
                throw ResolutionError.unspecifiedResolver(layer.rawValue)
            }
            throw error
        }
        let res = try getAddress(domain: domain, network: network, token: token) as? [String: Any]

        if let val = res?["0"] as? String {
            if !val.isEmpty {
                return val
            }
        }
        return ""
    }

    func getAddress(domain: String, network: String, token: String) throws -> Any {
        let tokenID = super.namehash(domain: domain)
        if
            let result = try proxyReaderContract?
                .callMethod(
                    methodName: Self.getAddressMethodName,
                    args: [network, token, tokenID]
                ) {
            return result
        }
        throw ResolutionError.proxyReaderNonInitialized
    }

    // MARK: - Get Record

    func record(domain: String, key: String) throws -> String {
        let tokenID = super.namehash(domain: domain)
        let result = try recordFromTokenID(tokenID: tokenID, key: key)
        guard Utillities.isNotEmpty(result) else {
            throw ResolutionError.recordNotFound(layer.rawValue)
        }
        return result
    }

    func allRecords(domain: String) throws -> [String: String] {
        let commonRecordsKeys = try Self.parseRecordKeys()
        let mergedRecords = Array(Set(commonRecordsKeys!))
        return try records(keys: mergedRecords, for: domain).filter { !$0.value.isEmpty }
    }

    func records(keys: [String], for domain: String) throws -> [String: String] {
        let tokenID = super.namehash(domain: domain)

        guard
            let dict = try getDataForMany(keys: keys, for: [tokenID]) as? [String: Any],
            let owners = unfoldForMany(contractResult: dict, key: Contract.ownersKey),
            Utillities.isNotEmpty(owners[0])
        else {
            throw ResolutionError.unregisteredDomain
        }
        if
            let valuesArray = dict[Contract.valuesKey] as? [[String]],
            !valuesArray.isEmpty,
            !valuesArray[0].isEmpty {
            let result = valuesArray[0]
            return zip(keys, result).reduce(into: [String: String]()) { dict, pair in
                let (key, value) = pair
                dict[key] = value
            }
        }
        // The line below will never get executed.
        fatalError("Failed unwrapping the results")
    }

    func locations(domains: [String]) throws -> [String: Location] {
        let tokenIDs = domains.map { self.namehash(domain: $0) }
        var calls = tokenIDs.map { MultiCallData(methodName: Self.registryOfMethodName, args: [$0]) }
        calls.append(MultiCallData(methodName: Self.getDataForManyMethodName, args: [[], tokenIDs]))
        let multiCallBytes = try proxyReaderContract?.multiCall(calls: calls)
        return try parseMultiCallForLocations(multiCallBytes!, from: calls, for: domains)
    }

    func getTokenUri(tokenID: String) throws -> String {
        do {
            if
                let result = try proxyReaderContract?
                    .callMethod(
                        methodName: Self.tokenURIMethodName,
                        args: [tokenID]
                    ) {
                let dict = result as? [String: Any]
                if let val = dict?["0"] as? String {
                    if !val.isEmpty {
                        return val
                    }
                }
                throw ResolutionError.unregisteredDomain
            }
            throw ResolutionError.proxyReaderNonInitialized
        } catch ResolutionError.executionReverted {
            throw ResolutionError.unregisteredDomain
        }
    }

    func getDomainName(tokenID: String) throws -> String {
        let metadata = try getTokenUriMetadata(tokenID: tokenID)
        guard metadata.name != nil else {
            throw ResolutionError.unregisteredDomain
        }
        return metadata.name!
    }
    
    func reverseTokenID(address: String) throws -> String {
        let res = try getReverseResolution(address: address)
        let dict = res as? [String: Any]
        if let data = dict?["0"] as? BigUInt {
            let val = String(data, radix: 16)
            guard Utillities.isNotEmpty(val) else {
                throw ResolutionError.reverseResolutionNotSpecified
            }
            return "0x" + String(repeating: "0", count: max(0, 64 - val.count)) + val
        }
        throw ResolutionError.reverseResolutionNotSpecified
    }

    private func resolverFromTokenID(tokenID: String) throws -> String {
        let res: Any
        do {
            res = try getDataForMany(keys: [Contract.resolversKey, Contract.ownersKey], for: [tokenID])
            guard
                let owners = unfoldForMany(contractResult: res, key: Contract.ownersKey),
                Utillities.isNotEmpty(owners[0])
            else {
                throw ResolutionError.unregisteredDomain
            }
        } catch {
            if error is ABICoderError {
                throw ResolutionError.unspecifiedResolver(layer.rawValue)
            }
            throw error
        }
        guard
            let rec = unfoldForMany(contractResult: res, key: Contract.resolversKey),
            !rec.isEmpty
        else {
            throw ResolutionError.unspecifiedResolver(layer.rawValue)
        }
        guard Utillities.isNotEmpty(rec[0]) else {
            throw ResolutionError.unspecifiedResolver(layer.rawValue)
        }
        return rec[0]
    }

    private func recordFromTokenID(tokenID: String, key: String) throws -> String {
        let result: OwnerResolverRecord
        do {
            result = try getOwnerResolverRecord(tokenID: tokenID, key: key)
        } catch {
            if error is ABICoderError {
                throw ResolutionError.unspecifiedResolver(layer.rawValue)
            }
            throw error
        }
        guard Utillities.isNotEmpty(result.owner) else {
            throw ResolutionError.unregisteredDomain
        }
        guard Utillities.isNotEmpty(result.resolver) else {
            throw ResolutionError.unspecifiedResolver(layer.rawValue)
        }

        return result.record
    }

    // MARK: - Helper functions

    private func getTokenUriMetadata(tokenID: String) throws -> TokenUriMetadata {
        let tokenURI = try getTokenUri(tokenID: tokenID)
        guard !tokenURI.isEmpty else {
            throw ResolutionError.unregisteredDomain
        }

        let url = URL(string: tokenURI)
        let semaphore = DispatchSemaphore(value: 0)

        var tokenUriMetadataResult: Result<TokenUriMetadata, ResolutionError>!
        networking.makeHttpGetRequest(
            url: url!,
            completion: {
                tokenUriMetadataResult = $0
                semaphore.signal()
            }
        )
        semaphore.wait()

        switch tokenUriMetadataResult {
        case let .success(tokenUriMetadata):
            return tokenUriMetadata
        case let .failure(error):
            throw error
        case .none:
            throw ResolutionError.badRequestOrResponse
        }
    }

    private func parseMultiCallForLocations(
        _ multiCallBytes: [Data],
        from calls: [MultiCallData],
        for domains: [String]
    ) throws
        -> [String: Location] {
        var registries: [String] = []
        var owners: [String] = []
        var resolvers: [String] = []

        for (data, call) in zip(multiCallBytes, calls) {
            switch call.methodName {
            case Self.registryOfMethodName:
                let hexMessage = "0x" + data.toHexString()
                if
                    let result = try proxyReaderContract?.coder.decode(hexMessage, from: Self.registryOfMethodName),
                    let dict = result as? [String: Any],
                    let val = dict["0"] as? EthereumAddress {
                    registries.append(val._address)
                }

            case Self.getDataForManyMethodName:
                let hexMessage = "0x" + data.toHexString()
                if
                    let dict = try proxyReaderContract?.coder.decode(hexMessage, from: Self.getDataForManyMethodName),
                    let domainOwners = unfoldForMany(contractResult: dict, key: Contract.ownersKey),
                    let domainResolvers = unfoldForMany(contractResult: dict, key: Contract.resolversKey) {
                    owners += domainOwners
                    resolvers += domainResolvers
                }

            default:
                throw ResolutionError.methodNotSupported
            }
        }

        return buildLocations(domains: domains, owners: owners, resolvers: resolvers, registries: registries)
    }

    private func buildLocations(
        domains: [String],
        owners: [String],
        resolvers: [String],
        registries: [String]
    )
        -> [String: Location] {
        var locations: [String: Location] = [:]
        for (domain, (owner, (resolver, registry))) in zip(domains, zip(owners, zip(resolvers, registries))) {
            if Utillities.isNotEmpty(owner) {
                locations[domain] = Location(
                    registryAddress: registry,
                    resolverAddress: resolver,
                    networkID: CommonNamingService.networkIDs[network]!,
                    blockchain: blockchain,
                    owner: owner,
                    providerURL: providerURL
                )
            } else {
                locations[domain] = Location()
            }
        }
        return locations
    }

    private func unfoldAddress<T>(_ incomingData: T) -> String? {
        if let eth = incomingData as? EthereumAddress {
            return eth.address
        }
        if let str = incomingData as? String {
            return str
        }
        return nil
    }

    private func unfoldAddressForMany<T>(_ incomingData: T) -> [String]? {
        if let ethArray = incomingData as? [EthereumAddress] {
            return ethArray.map { $0.address }
        }
        if let strArray = incomingData as? [String] {
            return strArray
        }
        return nil
    }

    private func unfoldForMany(contractResult: Any, key: String = "0") -> [String]? {
        if
            let dict = contractResult as? [String: Any],
            let element = dict[key] {
            return unfoldAddressForMany(element)
        }
        return nil
    }

    private func getOwnerResolverRecord(tokenID: String, key: String) throws -> OwnerResolverRecord {
        let res = try getDataForMany(keys: [key], for: [tokenID])
        if let dict = res as? [String: Any] {
            if
                let owners = unfoldAddressForMany(dict[Contract.ownersKey]),
                let resolvers = unfoldAddressForMany(dict[Contract.resolversKey]),
                let valuesArray = dict[Contract.valuesKey] as? [[String]] {
                guard Utillities.isNotEmpty(owners[0]) else {
                    throw ResolutionError.unregisteredDomain
                }

                guard
                    Utillities.isNotEmpty(resolvers[0]),
                    !valuesArray.isEmpty,
                    !valuesArray[0].isEmpty
                else {
                    throw ResolutionError.unspecifiedResolver(layer.rawValue)
                }

                let record = valuesArray[0][0]
                return OwnerResolverRecord(owner: owners[0], resolver: resolvers[0], record: record)
            }
        }
        throw ResolutionError.unregisteredDomain
    }

    private func getReverseResolution(address: String) throws -> Any {
        if
            let result = try proxyReaderContract?
                .callMethod(
                    methodName: Self.reverseOfMethodName,
                    args: [address]
                ) {
            return result
        }
        throw ResolutionError.proxyReaderNonInitialized
    }
    
    private func getDataForMany(keys: [String], for tokenIDs: [String]) throws -> Any {
        if
            let result = try proxyReaderContract?
                .callMethod(
                    methodName: Self.getDataForManyMethodName,
                    args: [keys, tokenIDs]
                ) {
            return result
        }
        throw ResolutionError.proxyReaderNonInitialized
    }

    private func getRegistryAddress(tokenID: String) throws -> String {
        do {
            if
                let result = try proxyReaderContract?
                    .callMethod(
                        methodName: Self.registryOfMethodName,
                        args: [tokenID]
                    ) {
                let dict = result as? [String: Any]
                if let val = dict?["0"] as? EthereumAddress {
                    if !Utillities.isNotEmpty(val.address) {
                        throw ResolutionError.unregisteredDomain
                    }
                    return val.address
                }
                throw ResolutionError.unregisteredDomain
            }
            throw ResolutionError.proxyReaderNonInitialized
        } catch ResolutionError.executionReverted {
            throw ResolutionError.unregisteredDomain
        }
    }
}

extension String {
    private var normalized32: String {
        let droppedHexPrefix = hasPrefix("0x") ? String(dropFirst("0x".count)) : self
        let cleanAddress = droppedHexPrefix.lowercased()
        if cleanAddress.count < 64 {
            let zeroCharacter: Character = "0"
            let arr = Array(repeating: zeroCharacter, count: 64 - cleanAddress.count)
            let zeros = String(arr)

            return "0x" + zeros + cleanAddress
        }
        return "0x" + cleanAddress
    }
}

extension Data {
    private init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else {
            return nil
        }

        let chars = hex.map { $0 }
        let bytes = stride(from: 0, to: chars.count, by: 2)
            .map { String(chars[$0]) + String(chars[$0 + 1]) }
            .compactMap { UInt8($0, radix: 16) }

        guard hex.count / bytes.count == 2 else {
            return nil
        }
        self.init(bytes)
    }
}
