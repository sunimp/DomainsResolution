//
//  ABIExtensions.swift
//  DomainsResolution
//
//  Created by Sun on 2021/2/16.
//

import BigInt
import Foundation

extension Data {
    func setLengthLeft(_ toBytes: UInt64, isNegative: Bool = false) -> Data? {
        let existingLength = UInt64(count)
        if existingLength == toBytes {
            return Data(self)
        } else if existingLength > toBytes {
            return nil
        }
        var data =
            if isNegative {
                Data(repeating: UInt8(255), count: Int(toBytes - existingLength))
            } else {
                Data(repeating: UInt8(0), count: Int(toBytes - existingLength))
            }
        data.append(self)
        return data
    }

    func setLengthRight(_ toBytes: UInt64, isNegative: Bool = false) -> Data? {
        let existingLength = UInt64(count)
        if existingLength == toBytes {
            return Data(self)
        } else if existingLength > toBytes {
            return nil
        }
        var data = Data()
        data.append(self)
        if isNegative {
            data.append(Data(repeating: UInt8(255), count: Int(toBytes - existingLength)))
        } else {
            data.append(Data(repeating: UInt8(0), count: Int(toBytes - existingLength)))
        }
        return data
    }

    static func fromHex(_ hex: String) -> Data? {
        let string = hex.lowercased().stripHexPrefix()
        let array = [UInt8](hex: string)
        if array.isEmpty {
            if hex == "0x" || hex == "" {
                return Data()
            } else {
                return nil
            }
        }
        return Data(array)
    }
}

extension BigInt {
    func toTwosComplement() -> Data {
        if sign == BigInt.Sign.plus {
            return magnitude.serialize()
        } else {
            let serializedLength = magnitude.serialize().count
            let MAX = BigUInt(1) << (serializedLength * 8)
            let twoComplement = MAX - magnitude
            return twoComplement.serialize()
        }
    }
}

extension BigUInt {
    func abiEncode(bits: UInt64) -> Data? {
        let data = serialize()
        let paddedLength = UInt64((bits + 7) / 8)
        return data.setLengthLeft(paddedLength)
    }
}

extension BigInt {
    func abiEncode(bits: UInt64) -> Data? {
        let isNegative = self < BigInt(0)
        let data = toTwosComplement()
        let paddedLength = UInt64((bits + 7) / 8)
        return data.setLengthLeft(paddedLength, isNegative: isNegative)
    }
}

extension BigInt {
    static func fromTwosComplement(data: Data) -> BigInt {
        let isPositive = ((data[0] & 128) >> 7) == 0
        if isPositive {
            let magnitude = BigUInt(data)
            return BigInt(magnitude)
        } else {
            let MAX = (BigUInt(1) << (data.count * 8))
            let magnitude = MAX - BigUInt(data)
            return BigInt(0) - BigInt(magnitude)
        }
    }
}

extension String {
    var fullRange: Range<Index> {
        startIndex ..< endIndex
    }

    var fullNSRange: NSRange {
        NSRange(fullRange, in: self)
    }

    func index(of char: Character) -> Index? {
        guard let range = range(of: String(char)) else {
            return nil
        }
        return range.lowerBound
    }

    subscript(bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start ... end])
    }

    subscript(bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start ..< end])
    }

    subscript(bounds: CountablePartialRangeFrom<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = endIndex
        return String(self[start ..< end])
    }

    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let stringLength = count
        if stringLength < toLength {
            return String(repeatElement(character, count: toLength - stringLength)) + self
        } else {
            return String(suffix(toLength))
        }
    }

    func hasHexPrefix() -> Bool {
        hasPrefix("0x")
    }

    func stripHexPrefix() -> String {
        if hasPrefix("0x") {
            let indexStart = index(startIndex, offsetBy: 2)
            return String(self[indexStart...])
        }
        return self
    }

    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else {
            return []
        }
        let nsString = self as NSString
        let results = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
        return results.map { result in
            (0 ..< result.numberOfRanges).map { result.range(at: $0).location != NSNotFound
                ? nsString.substring(with: result.range(at: $0))
                : ""
            }
        }
    }

    func range(from nsRange: NSRange) -> Range<String.Index>? {
        guard
            let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
            let to16 = utf16.index(
                utf16.startIndex,
                offsetBy: nsRange.location + nsRange.length,
                limitedBy: utf16.endIndex
            ),
            let from = from16.samePosition(in: self),
            let to = to16.samePosition(in: self)
        else {
            return nil
        }
        return from ..< to
    }

    var asciiValue: Int {
        let s = unicodeScalars
        return Int(s[s.startIndex].value)
    }
}

extension Character {
    var asciiValue: Int {
        let s = String(self).unicodeScalars
        return Int(s[s.startIndex].value)
    }
}

extension [UInt8] {
    init(hex: String) {
        self.init()
        reserveCapacity(hex.unicodeScalars.lazy.underestimatedCount)
        var buffer: UInt8?
        var skip = hex.hasPrefix("0x") ? 2 : 0
        for char in hex.unicodeScalars.lazy {
            guard skip == 0 else {
                skip -= 1
                continue
            }
            guard char.value >= 48, char.value <= 102 else {
                removeAll()
                return
            }
            let v: UInt8
            let c = UInt8(char.value)
            switch c {
            case let c where c <= 57:
                v = c - 48
            case let c where c >= 65 && c <= 70:
                v = c - 55
            case let c where c >= 97:
                v = c - 87
            default:
                removeAll()
                return
            }
            if let b = buffer {
                append(b << 4 | v)
                buffer = nil
            } else {
                buffer = v
            }
        }
        if let b = buffer {
            append(b)
        }
    }

    func toHexString() -> String {
        `lazy`.reduce("") {
            var s = String($1, radix: 16)
            if s.count == 1 {
                s = "0" + s
            }
            return $0 + s
        }
    }
}
