//
//  TestHelpers.swift
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

// MARK: - TestHelpers

class TestHelpers {
    // MARK: Nested Types

    enum DOMAINS {
        case DOMAIN
        case WALLET_DOMAIN
        case UNNORMALIZED_DOMAIN
        case DOMAIN2
        case DOMAIN3
        case UNREGISTERED_DOMAIN
        case UNREGISTERED_ZIL
        case ZIL_DOMAIN
        case LAYER2_DOMAIN
    }

    // MARK: Static Properties

    static let TEST_DOMAINS: [DOMAINS: String] = [
        .DOMAIN: "reseller-test-udtesting-459239285.crypto",
        .WALLET_DOMAIN: "uns-devtest-265f8f.wallet",
        .UNNORMALIZED_DOMAIN: "    uns-dEVtest-265f8f.wallet    ",
        .DOMAIN2: "cryptoalpaca9798.blockchain",
        .DOMAIN3: "uns-devtest-3b1663.x",
        .UNREGISTERED_DOMAIN: "unregistered.crypto",
        .UNREGISTERED_ZIL: "unregistered.zil",
        .ZIL_DOMAIN: "test-udtesting-654.zil",
        .LAYER2_DOMAIN: "udtestdev-test-l2-domain-784391.wallet",
    ]

    // MARK: Static Functions

    static func getTestDomain(_ type: DOMAINS) -> String {
        TEST_DOMAINS[type]!
    }

    static func checkError(completion: @escaping () throws -> Void, expectedError: ResolutionError) {
        do {
            try completion()
            XCTFail("Expected \(expectedError), but got none")
        } catch {
            if let catched = error as? ResolutionError {
                assert(catched == expectedError, "Expected \(expectedError), but got \(catched)")
                return
            }
            XCTFail("Expected ResolutionError, but got different \(error)")
        }
    }

    static func checkError<T>(result: Result<T, ResolutionError>, expectedError: ResolutionError) {
        switch result {
        case .success:
            XCTFail("Expected \(expectedError), but got none")
        case let .failure(error):
            assert(error == expectedError, "Expected \(expectedError), but got \(error)")
            return
        }
    }
}

// MARK: - ResolutionError + Equatable

extension ResolutionError: Equatable {
    public static func == (lhs: ResolutionError, rhs: ResolutionError) -> Bool {
        switch (lhs, rhs) {
        case (.unregisteredDomain, .unregisteredDomain):
            true
        case (.unsupportedDomain, .unsupportedDomain):
            true
        case (.recordNotFound, .recordNotFound):
            true
        case (.recordNotSupported, .recordNotSupported):
            true
        case (.unsupportedNetwork, .unsupportedNetwork):
            true
        case (.unspecifiedResolver, .unspecifiedResolver):
            true
        case (.proxyReaderNonInitialized, .proxyReaderNonInitialized):
            true
        case (.inconsistentDomainArray, .inconsistentDomainArray):
            true
        case (.methodNotSupported, .methodNotSupported):
            true
        case (.tooManyResponses, .tooManyResponses):
            true
        case (.badRequestOrResponse, .badRequestOrResponse):
            true
        case (.unsupportedServiceName, .unsupportedServiceName):
            true
        case (.registryAddressIsNotProvided, .registryAddressIsNotProvided):
            true
        case (.invalidDomainName, .invalidDomainName):
            true
        case (.reverseResolutionNotSpecified, .reverseResolutionNotSpecified):
            true
        case (.unregisteredDomain, _),
             (.unsupportedDomain, _),
             (.recordNotFound, _),
             (.recordNotSupported, _),
             (.unsupportedNetwork, _),
             (.unspecifiedResolver, _),
             (.unknownError, _),
             (.inconsistentDomainArray, _),
             (.methodNotSupported, _),
             (.proxyReaderNonInitialized, _),
             (.tooManyResponses, _),
             (.badRequestOrResponse, _),
             (.unsupportedServiceName, _),
             (.registryAddressIsNotProvided, _),
             (.invalidDomainName, _):

            false
        // Xcode with Version 12.4 (12D4e) can't compile this without default
        // throws error: The compiler is unable to check that this switch is exhaustive in a reasonable time
        default:
            false
        }
    }
}
