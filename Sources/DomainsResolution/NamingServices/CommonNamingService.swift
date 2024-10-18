//
//  CommonNamingService.swift
//  DomainsResolution
//
//  Created by Sun on 2020/8/20.
//

import Foundation

// MARK: - CommonNamingService

class CommonNamingService {
    // MARK: Nested Types

    enum ContractType: String {
        case unsRegistry = "UNSRegistry"
        case cnsRegistry = "CNSRegistry"
        case ensRegistry = "ENSRegistry"
        case resolver = "Resolver"
        case proxyReader = "ProxyReader"

        // MARK: Computed Properties

        var name: String {
            rawValue
        }
    }

    // MARK: Static Properties

    static let hexadecimalPrefix = "0x"
    static let jsonExtension = "json"

    // MARK: Properties

    let name: NamingServiceName
    let providerURL: String
    let networking: NetworkingLayer

    // MARK: Lifecycle

    init(name: NamingServiceName, providerURL: String, networking: NetworkingLayer) {
        self.name = name
        self.providerURL = providerURL
        self.networking = networking
    }

    // MARK: Functions

    func buildContract(address: String, type: ContractType) throws -> Contract {
        try buildContract(address: address, type: type, providerURL: providerURL)
    }

    func buildContract(address: String, type: ContractType, providerURL: String) throws -> Contract {
        let jsonFileName: String
        let url = providerURL
        let nameLowCased = name.rawValue.lowercased()
        switch type {
        case .unsRegistry:
            jsonFileName = "\(nameLowCased)Registry"
        case .ensRegistry:
            jsonFileName = "\(nameLowCased)Registry"
        case .cnsRegistry:
            jsonFileName = "cnsRegistry"
        case .resolver:
            jsonFileName = "\(nameLowCased)Resolver"
        case .proxyReader:
            jsonFileName = "\(nameLowCased)ProxyReader"
        }

        let abi: ABIContract = try parseAbi(fromFile: jsonFileName)!
        return Contract(providerURL: url, address: address, abi: abi, networking: networking)
    }

    func parseAbi(fromFile name: String) throws -> ABIContract? {
        #if INSIDE_PM
        let bundler = Bundle.module
        #else
        let bundler = Bundle(for: type(of: self))
        #endif
        if let filePath = bundler.url(forResource: name, withExtension: "json") {
            let data = try Data(contentsOf: filePath)
            let jsonDecoder = JSONDecoder()
            let abi = try jsonDecoder.decode([ABI.Record].self, from: data)
            return try abi.map { record -> ABI.Element in
                return try record.parse()
            }
        }
        return nil
    }

    func namehash(domain: String) -> String {
        var node = [UInt8](repeating: 0x0, count: 32)
        if !domain.isEmpty {
            node = domain.split(separator: ".")
                .map { Array($0.utf8) }
                .reversed()
                .reduce(node) { self.childHash(parent: $0, label: $1) }
        }
        return "\(Self.hexadecimalPrefix)\(node.toHexString())"
    }

    func childHash(parent: [UInt8], label: [UInt8]) -> [UInt8] {
        let childHash = label.sha3(.keccak256)
        return (parent + childHash).sha3(.keccak256)
    }
}

extension CommonNamingService {
    static let networkConfigFileName = "uns-config"
    static let recordKeysFileName = "resolver-keys"
    static let networkIDs = [
        "mainnet": "1",
        "ropsten": "3",
        "goerli": "5",
        "polygon-mumbai": "80001",
        "polygon-mainnet": "137",
    ]
    static let networkToBlockchain = [
        "mainnet": "ETH",
        "goerli": "ETH",
        "polygon-mumbai": "MATIC",
        "polygon-mainnet": "MATIC",
    ]

    struct NewtorkConfigJson: Decodable {
        let version: String
        let networks: [String: ContractsEntry]
    }

    struct ResolverKeysJson: Decodable {
        let version: String
        let keys: [String: RecordEntry]
    }

    struct RecordEntry: Decodable {
        let deprecatedKeyName: String
        let deprecated: Bool
        let validationRegex: String?
    }

    struct ContractsEntry: Decodable {
        let contracts: [String: ContractAddressEntry]
    }

    struct ContractAddressEntry: Decodable {
        let address: String
        let legacyAddresses: [String]
        let deploymentBlock: String
    }

    static func parseContractAddresses(network: String) throws -> [String: ContractAddressEntry]? {
        #if INSIDE_PM
        let bundler = Bundle.module
        #else
        let bundler = Bundle(for: self)
        #endif

        guard let idString = networkIDs[network] else {
            return nil
        }

        if let filePath = bundler.url(forResource: Self.networkConfigFileName, withExtension: "json") {
            guard let data = try? Data(contentsOf: filePath) else {
                return nil
            }
            guard let info = try? JSONDecoder().decode(NewtorkConfigJson.self, from: data) else {
                return nil
            }
            guard let currentNetwork = info.networks[idString] else {
                return nil
            }
            return currentNetwork.contracts
        }
        return nil
    }

    static func parseRecordKeys() throws -> [String]? {
        #if INSIDE_PM
        let bundler = Bundle.module
        #else
        let bundler = Bundle(for: self)
        #endif

        if let filePath = bundler.url(forResource: Self.recordKeysFileName, withExtension: "json") {
            guard let data = try? Data(contentsOf: filePath) else {
                return nil
            }
            guard let recordFile = try? JSONDecoder().decode(ResolverKeysJson.self, from: data) else {
                return nil
            }
            let keyEntries = recordFile.keys
            return Array(keyEntries.keys)
        }
        return nil
    }

    static func getNetworkName(providerURL: String, networking: NetworkingLayer) throws -> String {
        let networkID = try Self.getNetworkID(providerURL: providerURL, networking: networking)
        return networkIDs.key(forValue: networkID) ?? ""
    }

    static func getNetworkID(providerURL: String, networking: NetworkingLayer) throws -> String {
        let url = URL(string: providerURL)!
        let payload = JsonRpcPayload(jsonrpc: "2.0", id: "67", method: "net_version", params: [])

        var resp: JsonRpcResponseArray?
        var err: Error?
        let semaphore = DispatchSemaphore(value: 0)

        try networking.makeHttpPostRequest(
            url: url,
            httpMethod: "POST",
            httpHeaderContentType: "application/json",
            httpBody: JSONEncoder().encode(payload)
        ) { result in
            switch result {
            case let .success(response):
                resp = response
            case let .failure(error):
                err = error
            }
            semaphore.signal()
        }
        semaphore.wait()
        guard err == nil else {
            throw err!
        }
        switch resp?[0].result {
        case let .string(result):
            return result
        default:
            return ""
        }
    }
}

extension Dictionary where Value: Equatable {
    fileprivate func key(forValue value: Value) -> Key? {
        first { $0.1 == value }?.0
    }
}
