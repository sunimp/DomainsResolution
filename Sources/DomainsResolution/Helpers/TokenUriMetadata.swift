//
//  TokenUriMetadata.swift
//  DomainsResolution
//
//  Created by Sun on 2021/7/21.
//

import Foundation

// MARK: - TokenUriMetadata

public struct TokenUriMetadata: Codable {
    // MARK: Nested Types

    enum CodingKeys: String, CodingKey {
        case name
        case tokenID
        case namehash
        case description
        case externalURL = "external_url"
        case image
        case attributes
        case backgroundColor = "background_color"
        case animationURL = "animation_url"
        case youtubeURL = "youtube_url"
        case externalLink = "external_link"
        case imageData = "image_data"
    }

    // MARK: Properties

    let name: String?
    let tokenID: String?
    let namehash: String?
    let description: String?
    let externalURL: String?
    let image: String?
    let attributes: [TokenUriMetadataAttribute]
    var backgroundColor: String?
    var animationURL: String?
    var youtubeURL: String?
    var externalLink: String?
    var imageData: String?
}

// MARK: - TokenUriMetadataAttribute

public struct TokenUriMetadataAttribute: Codable {
    // MARK: Nested Types

    enum CodingKeys: String, CodingKey {
        case displayType = "display_type"
        case traitType = "trait_type"
        case value
    }

    // MARK: Properties

    let displayType: String?
    let traitType: String?
    let value: TokenUriMetadataValue
}

// MARK: - TokenUriMetadataValue

struct TokenUriMetadataValue: Codable {
    // MARK: Properties

    let value: String

    // MARK: Lifecycle

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // attempt to decode from all JSON primitives
        if let str = try? container.decode(String.self) {
            value = str
        } else if let int = try? container.decode(Int.self) {
            value = int.description
        } else if let double = try? container.decode(Double.self) {
            value = double.description
        } else if let bool = try? container.decode(Bool.self) {
            value = bool.description
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Failed to decode token metadata attribute value."
                )
            )
        }
    }

    // MARK: Functions

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
