//
//  EthereumAddress.swift
//  DomainsResolution
//
//  Created by Sun on 2021/7/21.
//

import CryptoSwift
// swiftlint:disable all
import Foundation

// MARK: - EthereumAddress

public struct EthereumAddress: Equatable, ExpressibleByStringLiteral {
    // MARK: Nested Types

    public typealias StringLiteralType = String

    public enum AddressType {
        case normal
        case contractDeployment
    }

    // MARK: Properties

    public var type: AddressType = .normal

    var _address: String

    // MARK: Computed Properties

    public var isValid: Bool {
        switch type {
        case .normal:
            addressData.count == 20
        case .contractDeployment:
            true
        }
    }

    public var addressData: Data {
        switch type {
        case .normal:
            guard let dataArray = Data.fromHex(_address) else {
                return Data()
            }
            return dataArray

        //                guard let d = dataArray.setLengthLeft(20) else { return Data()}
        //                return d
        case .contractDeployment:
            return Data()
        }
    }

    public var address: String {
        switch type {
        case .normal:
            EthereumAddress.toChecksumAddress(_address)!
        case .contractDeployment:
            "0x"
        }
    }

    // MARK: Lifecycle

    public init(stringLiteral value: EthereumAddress.StringLiteralType) {
        self.init(value, type: .normal, ignoreChecksum: true)!
    }

    public init?(_ addressString: String, type: AddressType = .normal, ignoreChecksum: Bool = false) {
        switch type {
        case .normal:
            guard let data = Data.fromHex(addressString) else {
                return nil
            }
            guard data.count == 20 else {
                return nil
            }
            if !addressString.hasHexPrefix() {
                return nil
            }
            if !ignoreChecksum {
                // check for checksum
                if data.toHexString() == addressString.stripHexPrefix() {
                    _address = data.toHexString().addHexPrefix()
                    self.type = .normal
                    return
                } else if data.toHexString().uppercased() == addressString.stripHexPrefix() {
                    _address = data.toHexString().addHexPrefix()
                    self.type = .normal
                    return
                } else {
                    let checksummedAddress = EthereumAddress.toChecksumAddress(data.toHexString().addHexPrefix())
                    guard checksummedAddress == addressString else {
                        return nil
                    }
                    _address = data.toHexString().addHexPrefix()
                    self.type = .normal
                    return
                }
            } else {
                _address = data.toHexString().addHexPrefix()
                self.type = .normal
                return
            }

        case .contractDeployment:
            _address = "0x"
            self.type = .contractDeployment
        }
    }

    public init?(_ addressData: Data, type: AddressType = .normal) {
        guard addressData.count == 20 else {
            return nil
        }
        _address = addressData.toHexString().addHexPrefix()
        self.type = type
    }

    // MARK: Static Functions

    public static func == (lhs: EthereumAddress, rhs: EthereumAddress) -> Bool {
        lhs.addressData == rhs.addressData && lhs.type == rhs.type
        //        return lhs.address.lowercased() == rhs.address.lowercased() && lhs.type == rhs.type
    }

    public static func toChecksumAddress(_ addr: String) -> String? {
        let address = addr.lowercased().stripHexPrefix()
        guard let hash = address.data(using: .ascii)?.sha3(.keccak256).toHexString().stripHexPrefix()
        else {
            return nil
        }
        var ret = "0x"

        for (i, char) in address.enumerated() {
            let startIDx = hash.index(hash.startIndex, offsetBy: i)
            let endIDx = hash.index(hash.startIndex, offsetBy: i + 1)
            let hashChar = String(hash[startIDx ..< endIDx])
            let c = String(char)
            guard let int = Int(hashChar, radix: 16) else {
                return nil
            }
            if int >= 8 {
                ret += c.uppercased()
            } else {
                ret += c
            }
        }
        return ret
    }

    public static func contractDeploymentAddress() -> EthereumAddress {
        EthereumAddress("0x", type: .contractDeployment)!
    }

    //    public static func fromIBAN(_ iban: String) -> EthereumAddress {
    //
    //    }
}

// MARK: Hashable

extension EthereumAddress: Hashable { }
