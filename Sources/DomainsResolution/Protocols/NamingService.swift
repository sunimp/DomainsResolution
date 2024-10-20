//
//  NamingService.swift
//  DomainsResolution
//
//  Created by Sun on 2020/8/12.
//

import Foundation

protocol NamingService {
    var name: NamingServiceName { get }
    var providerURL: String { get }
    var networking: NetworkingLayer { get }

    func namehash(domain: String) -> String
    func isSupported(domain: String) -> Bool

    func owner(domain: String) throws -> String
    func addr(domain: String, ticker: String) throws -> String
    func addr(domain: String, network: String, token: String) throws -> String
    func resolver(domain: String) throws -> String

    func batchOwners(domains: [String]) throws -> [String: String?]

    func record(domain: String, key: String) throws -> String
    func records(keys: [String], for domain: String) throws -> [String: String]
    func allRecords(domain: String) throws -> [String: String]

    func getTokenUri(tokenID: String) throws -> String

    func getDomainName(tokenID: String) throws -> String

    func locations(domains: [String]) throws -> [String: Location]
}
