//
//  Configuration.swift
//  DomainsResolution
//
//  Created by Sun on 2024/8/21.
//

import Foundation

// MARK: - NamingServiceConfig

public struct NamingServiceConfig {
    let network: String
    let providerURL: String
    var networking: NetworkingLayer
    let proxyReader: String?
    let registryAddresses: [String]?
    
    public init(
        providerURL: String,
        network: String = "",
        networking: NetworkingLayer = DefaultNetworkingLayer(),
        proxyReader: String? = nil,
        registryAddresses: [String]? = nil
    ) {
        self.network = network
        self.providerURL = providerURL
        self.networking = networking
        self.proxyReader = proxyReader
        self.registryAddresses = registryAddresses
    }
}

// MARK: - UnsLocations

public struct UnsLocations {
    let layer1: NamingServiceConfig
    let layer2: NamingServiceConfig
    let znsLayer: NamingServiceConfig
    
    public init(
        layer1: NamingServiceConfig,
        layer2: NamingServiceConfig,
        znsLayer: NamingServiceConfig
    ) {
        self.layer1 = layer1
        self.layer2 = layer2
        self.znsLayer = znsLayer
    }
}

let UD_RPC_PROXY_BASE_URL = "https://api.unstoppabledomains.com/resolve"

// MARK: - Configurations

public struct Configurations {
    let uns: UnsLocations
    let apiKey: String? = nil
    
    public init(
        uns: UnsLocations
    ) {
        self.uns = uns
    }

    public init(
        apiKey: String,
        znsLayer: NamingServiceConfig = NamingServiceConfig(
            providerURL: "https://api.zilliqa.com",
            network: "mainnet"
        )
    ) {
        var networking = DefaultNetworkingLayer()
        networking.addHeader(header: "Authorization", value: "Bearer \(apiKey)")
        networking.addHeader(header: "X-Lib-Agent", value: Configurations.getLibVersion())

        let layer1NamingService = NamingServiceConfig(
            providerURL: "\(UD_RPC_PROXY_BASE_URL)/chains/eth/rpc",
            network: "mainnet",
            networking: networking
        )

        let layer2NamingService = NamingServiceConfig(
            providerURL: "\(UD_RPC_PROXY_BASE_URL)/chains/matic/rpc",
            network: "polygon-mainnet",
            networking: networking
        )

        uns = UnsLocations(
            layer1: layer1NamingService,
            layer2: layer2NamingService,
            znsLayer: znsLayer
        )
    }

    public static func getLibVersion() -> String {
        "UnstoppableDomains/resolution-swift/6.2.2"
    }
}
