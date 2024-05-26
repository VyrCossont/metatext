// Copyright © 2024 Vyr Cossont. All rights reserved.

import CoreGraphics
import Foundation

/// Decode and encode 6-digit CSS hex colors as strings.
/// Unspecified colors map to the empty string.
public struct HexColor: Hashable {
    /// If set, this has 3 elements.
    public let rgb: [UInt8]?

    public init(r: UInt8, g: UInt8, b: UInt8) {
        rgb = [r, g, b]
    }

    init() {
        rgb = nil
    }

    public init(_ string: String) {
        guard !string.isEmpty,
              string.hasPrefix("#"),
              string.count == 7
        else {
            rgb = nil
            return
        }

        let start = string.index(after: string.startIndex)
        let rgSplit = string.index(start, offsetBy: 2)
        let gbSplit = string.index(rgSplit, offsetBy: 2)
        let end = string.endIndex
        guard let r = UInt8(string[start..<rgSplit], radix: 16),
              let g = UInt8(string[rgSplit..<gbSplit], radix: 16),
              let b = UInt8(string[gbSplit..<end], radix: 16)
        else {
            rgb = nil
            return
        }

        rgb = [r, g, b]
    }

    public static let none: Self = .init()
}

extension HexColor: CustomStringConvertible {
    public var description: String {
        guard let rgb = rgb else { return "" }

        let rString = "\(rgb[0] < 0x10 ? "0" : "")\(String(rgb[0], radix: 16))"
        let gString = "\(rgb[1] < 0x10 ? "0" : "")\(String(rgb[1], radix: 16))"
        let bString = "\(rgb[2] < 0x10 ? "0" : "")\(String(rgb[2], radix: 16))"

        return "#\(rString)\(gString)\(bString)"
    }
}

extension HexColor: Decodable {
    public init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        self = .init(string)
    }
}

extension HexColor: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
