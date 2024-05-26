// Copyright © 2024 Vyr Cossont. All rights reserved.

import CoreGraphics
import Mastodon

/// Convert to and from `CGColor`.
extension HexColor {
    public init(_ cgColor: CGColor?) {
        guard let cgColor = cgColor,
              let srgbColorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let srgbColor = cgColor.converted(to: srgbColorSpace, intent: .relativeColorimetric, options: nil),
              let srgbComponents = srgbColor.components
        else {
            self = .none
            return
        }

        self.init(
            r: UInt8(srgbComponents[0] * CGFloat(0xff)),
            g: UInt8(srgbComponents[1] * CGFloat(0xff)),
            b: UInt8(srgbComponents[2] * CGFloat(0xff))
        )
    }

    public var cgColor: CGColor? {
        guard let rgb = rgb else { return nil }

        return .init(
            srgbRed: CGFloat(rgb[0]) / CGFloat(0xff),
            green: CGFloat(rgb[1]) / CGFloat(0xff),
            blue: CGFloat(rgb[2]) / CGFloat(0xff),
            alpha: 1
        )
    }
}
