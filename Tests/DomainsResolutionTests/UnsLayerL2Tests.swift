//
//  UnsLayerL2Tests.swift
//  DomainsResolution
//
//  Created by Sun on 2024/8/13.
//

import XCTest

#if INSIDE_PM
@testable import DomainsResolution
#else
@testable import Resolution
#endif

// MARK: - UnsLayerL2Tests

class UnsLayerL2Tests: XCTestCase {
    // MARK: Properties

    var unsLayer: UNSLayer!

    // MARK: Overridden Functions

    override func setUp() {
        let providerURL = try! ResolutionTests.getL2TestNetRpcURL()
        let config = NamingServiceConfig(
            providerURL: providerURL,
            network: "polygon-mumbai"
        )
        let contracts: [UNSContract] = [
            UNSContract(
                name: "UNSRegistry",
                contract: Contract(
                    providerURL: providerURL,
                    address: "0x2a93C52E7B6E7054870758e15A1446E769EdfB93",
                    abi: try! parseAbi(fromFile: "unsRegistry")!,
                    networking: DefaultNetworkingLayer()
                ),
                deploymentBlock: "0x01213f43"
            ),
            UNSContract(
                name: "ProxyReader",
                contract: Contract(
                    providerURL: providerURL,
                    address: "0xBD4674F11d512120dFc8BAe5f84963d7419A5db2",
                    abi: try! parseAbi(fromFile: "unsProxyReader")!,
                    networking: DefaultNetworkingLayer()
                ),
                deploymentBlock: "0x01213f87"
            ),
        ]
        unsLayer = try! UNSLayer(name: .layer2, config: config, contracts: contracts)
    }

    // MARK: Functions

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
    
    /// All functions of Layer2 except batchOwner should throw UnregisteredDomain when domain does not exists
    /// functions like batchOwner will return either array full of nil or empty [String]
    /// It is expected to parse and combine the results of above functions with results from layer1
    func testUnregistered() throws {
        let domain = TestHelpers.getTestDomain(.UNREGISTERED_DOMAIN)
        let tokenID = "0x6d8b296e38dfd295f2f4feb9ef2721c48210b7d77c0a08867123d9bd5150cf47"
        TestHelpers.checkError(
            completion: { _ = try self.unsLayer.owner(domain: domain) },
            expectedError: ResolutionError.unregisteredDomain
        )
        TestHelpers.checkError(
            completion: { _ = try self.unsLayer.addr(domain: domain, ticker: "whatever") },
            expectedError: ResolutionError.unregisteredDomain
        )
        TestHelpers.checkError(
            completion: { _ = try self.unsLayer.getDomainName(tokenID: tokenID) },
            expectedError: ResolutionError.unregisteredDomain
        )
        TestHelpers.checkError(
            completion: { _ = try self.unsLayer.getTokenUri(tokenID: tokenID) },
            expectedError: ResolutionError.unregisteredDomain
        )
        TestHelpers.checkError(
            completion: { _ = try self.unsLayer.record(domain: domain, key: "whatever") },
            expectedError: ResolutionError.unregisteredDomain
        )
        TestHelpers.checkError(
            completion: { _ = try self.unsLayer.records(keys: ["whatever"], for: domain) },
            expectedError: ResolutionError.unregisteredDomain
        )
        TestHelpers.checkError(
            completion: { _ = try self.unsLayer.resolver(domain: domain) },
            expectedError: ResolutionError.unregisteredDomain
        )
    }
}
