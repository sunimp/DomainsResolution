//
//  Utilities.swift
//  DomainsResolution
//
//  Created by Sun on 2020/8/20.
//

import Foundation

// MARK: - Utillities

class Utillities {
    static func isNotEmpty(_ value: String?) -> Bool {
        guard let value else {
            return false
        }
        return Self.isNotEmpty(value)
    }

    static func isNotEmpty(_ value: String) -> Bool {
        let nullValues = [
            "0",
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000000000000000000000000000",
        ]
        return !(value.isEmpty || nullValues.contains(value))
    }

    static func isNotEmpty(_ array: [Any]) -> Bool {
        !array.isEmpty
    }

    static func getLayerResultWrapper<T>(
        from results: [UNSLocation: AsyncConsumer<T>],
        for location: UNSLocation
    )
        -> AsyncConsumer<T> {
        results[location] ?? (nil, nil)
    }

    static func getLayerResult<T>(from results: [UNSLocation: AsyncConsumer<T>], for location: UNSLocation) -> T {
        let wrapper = Self.getLayerResultWrapper(from: results, for: location)
        return wrapper.0!
    }
    
    static func isUnregisteredDomain(error: Error?) -> Bool {
        isResolutionError(expected: ResolutionError.unregisteredDomain, error: error)
    }
    
    static func isResolutionError(expected: ResolutionError, error: Error?) -> Bool {
        if let error = error as? ResolutionError {
            if expected._code == error._code {
                return true
            }
        }
        return false
    }
}

extension String {
    static func ~= (lhs: String, rhs: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: rhs) else {
            return false
        }
        let range = NSRange(location: 0, length: lhs.utf16.count)
        return regex.firstMatch(in: lhs, options: [], range: range) != nil
    }

    func addHexPrefix() -> String {
        if !hasPrefix("0x") {
            return "0x" + self
        }
        return self
    }
}
