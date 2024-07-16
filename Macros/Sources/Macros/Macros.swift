// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A macro that produces both a value and a string containing the
/// source code that generated the value. For example,
///
///     #stringify(x + y)
///
/// produces a tuple `(x + y, "x + y")`.
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MacroImplementations", type: "StringifyMacro")

/// Similar to `Unknowable` but capable of storing the actual value when it doesn't match a known value.
public protocol PassthroughUnknowable: RawRepresentable {
    static var knownCases: [Self] { get }
}

/// Macro that implements conformance to `PassthroughUnknowable`.
/// Requires an inner enum named `KnownCases`.
@attached(member, names: named(RawValue), named(rawValue), named(`init`), named(knownCases), arbitrary)
@attached(extension, conformances: PassthroughUnknowable)
public macro PassthroughUnknowable() = #externalMacro(module: "MacroImplementations", type: "PassthroughUnknowableMacro")
