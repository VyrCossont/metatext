// Copyright © 2020 Metabolist. All rights reserved.

import Foundation
import HTTP
import UIKit

/// Wraps errors for display to the user.
public struct AlertItem: Identifiable {
    public let id = UUID()
    public let error: Error
    private let alertLocation: DebugLocation

    public init(
        error: Error,
        file: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) {
        self.error = error
        self.alertLocation = .init(file: file, line: line, function: function)
    }

    public var title: String { String(describing: type(of: error)) }
    public var message: String { error.localizedDescription }

    enum CodingKeys: String, CodingKey {
        case alertLocation
        case app
        case system

        case title
        case message

        case type
        case error
    }

    @MainActor
    public var json: Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(Report(self)) else { return nil }

        return data
    }

    public var text: Data {
        "\(title)\n\n\(message)".data(using: .utf8) ?? Data()
    }

    /// Enriches errors with metadata and encodes them to JSON for manual reporting.
    private struct Report: Encodable {
        let title: String
        let message: String
        let alertLocation: DebugLocation
        let app: App
        let system: System
        let error: Error

        @MainActor
        init(_ alertItem: AlertItem) {
            self.title = alertItem.title
            self.message = alertItem.message
            self.alertLocation = alertItem.alertLocation
            self.app = App()
            self.system = System()
            self.error = alertItem.error
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(title, forKey: .title)
            try container.encode(message, forKey: .message)
            try container.encode(alertLocation, forKey: .alertLocation)
            try container.encode(app, forKey: .app)
            try container.encode(system, forKey: .system)

            try container.encode(String(describing: type(of: error)), forKey: .type)
            if let encodableError = error as? any Encodable {
                try container.encode(encodableError, forKey: .error)
            }

        }

        /// Metadata about the app.
        struct App: Encodable {
            let bundle: String?
            let version: String?
            let build: String?

            init() {
                self.bundle = Bundle.main.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) as? String
                self.version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                self.build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
            }
        }

        /// Metadata about the device we're runnong on.
        struct System: Encodable {
            let name: String
            let version: String
            let model: String
            let idiom: String

            @MainActor
            init() {
                self.name = UIDevice.current.systemName
                self.version = UIDevice.current.systemVersion
                self.model = UIDevice.current.model
                switch UIDevice.current.userInterfaceIdiom {
                case .unspecified:
                    self.idiom = "unspecified"
                case .phone:
                    self.idiom = "phone"
                case .pad:
                    self.idiom = "pad"
                case .tv:
                    self.idiom = "tv"
                case .carPlay:
                    self.idiom = "carPlay"
                case .mac:
                    self.idiom = "mac"
                case .vision:
                    self.idiom = "vision"
                @unknown default:
                    self.idiom = "unknown"
                }
            }
        }
    }
}
