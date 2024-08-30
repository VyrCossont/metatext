// Copyright © 2024 Vyr Cossont. All rights reserved.

import Foundation
import Macros

/// List of known content types.
@PassthroughUnknowable
public enum ContentType {
    private enum KnownCases: String {
        case text = "text/plain"
        case markdown = "text/markdown"
        case html = "text/html"
        case bbcode = "text/bbcode"
        case mfm = "text/x.misskeymarkdown"
    }
}
