import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(MacroImplementations)
import MacroImplementations

let testMacros: [String: Macro.Type] = [
    "PassthroughUnknowable": PassthroughUnknowableMacro.self,
]
#endif

final class MacroTests: XCTestCase {
    func testMacro() throws {
        #if canImport(MacroImplementations)
        assertMacroExpansion(
            """
            @PassthroughUnknowable
            enum Bricks {
                private enum KnownCases: String {
                    case mud
                    case clay
                }
            }
            """,
            expandedSource: """
            enum Bricks {
                private enum KnownCases: String {
                    case mud
                    case clay
                }

                typealias RawValue = String

                case mud

                case clay

                case unknown(_ rawValue: RawValue)

                init(rawValue: RawValue) {
                    switch rawValue {
                    case KnownCases.mud.rawValue:
                        self = .mud;
                    case KnownCases.clay.rawValue:
                        self = .clay;
                    default:
                        self = .unknown(rawValue)
                    }
                }

                var rawValue: RawValue {
                    switch self {
                    case .mud:
                        KnownCases.mud.rawValue;
                    case .clay:
                        KnownCases.clay.rawValue;
                    case let .unknown(rawValue):
                        rawValue
                    }
                }

                static var knownCases: [Self] {
                    [.mud, .clay]
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
