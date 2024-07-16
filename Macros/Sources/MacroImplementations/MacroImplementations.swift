import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct MacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        PassthroughUnknowableMacro.self,
    ]
}

// PassthroughUnknowableMacro copies heavily from Swift's own OptionSetMacro, including comments.

enum PassthroughUnknowableMacroDiagnostic {
    case requiresStruct
    case requiresStringLiteral(String)
    case requiresKnownCasesEnum(String)
    case requiresKnownCasesEnumRawType
}

extension PassthroughUnknowableMacroDiagnostic: DiagnosticMessage {
    func diagnose<Node: SyntaxProtocol>(at node: Node) -> Diagnostic {
        Diagnostic(node: Syntax(node), message: self)
    }

    var message: String {
        switch self {
        case .requiresStruct:
            return "'PassthroughUnknowable' macro can only be applied to a struct"

        case .requiresStringLiteral(let name):
            return "'PassthroughUnknowable' macro argument \(name) must be a string literal"

        case .requiresKnownCasesEnum(let name):
          return "'PassthroughUnknowable' macro requires nested options enum '\(name)'"

        case .requiresKnownCasesEnumRawType:
          return "'PassthroughUnknowable' macro requires a raw type"
        }
    }

    var severity: DiagnosticSeverity { .error }

    var diagnosticID: MessageID {
        MessageID(domain: "Swift", id: "PassthroughUnknowable.\(self)")
    }
}

/// The label used for the OptionSet macro argument that provides the name of
/// the nested options enum.
private let knownCasesEnumNameArgumentLabel = "knownCasesName"

/// The default name used for the nested "KnownCases" enum.
private let defaultKnownCasesEnumName = "KnownCases"

extension LabeledExprListSyntax {
    /// Retrieve the first element with the given label.
    func first(labeled name: String) -> Element? {
        return first { element in
            if let label = element.label, label.text == name {
                return true
            }

            return false
        }
    }
}

/// Implements `@PassthroughUnknowable`.
public struct PassthroughUnknowableMacro {
    /// Decodes the arguments to the macro expansion.
    ///
    /// - Returns: the important arguments used by the various roles of this
    /// macro inhabits, or nil if an error occurred.
    static func decodeExpansion<
        Decl: DeclGroupSyntax,
        Context: MacroExpansionContext
    >(
        of attribute: AttributeSyntax,
        attachedTo decl: Decl,
        in context: Context
    ) -> (EnumDeclSyntax, EnumDeclSyntax, TypeSyntax)? {
        // Determine the name of the known cases enum.
        let knownCasesEnumName: String
        if case let .argumentList(arguments) = attribute.arguments,
            let knownCasesEnumNameArg = arguments.first(labeled: knownCasesEnumNameArgumentLabel) {
            // We have a known cases name; make sure it is a string literal.
            guard let stringLiteral = knownCasesEnumNameArg.expression.as(StringLiteralExprSyntax.self),
                  stringLiteral.segments.count == 1,
                  case let .stringSegment(knownCasesEnumNameString)? = stringLiteral.segments.first else {
                context.diagnose(
                    PassthroughUnknowableMacroDiagnostic
                        .requiresStringLiteral(knownCasesEnumNameArgumentLabel)
                        .diagnose(at: knownCasesEnumNameArg.expression)
                )
                return nil
            }

            knownCasesEnumName = knownCasesEnumNameString.content.text
        } else {
            knownCasesEnumName = defaultKnownCasesEnumName
        }

        // Only apply to enums.
        guard let enumDecl = decl.as(EnumDeclSyntax.self) else {
            context.diagnose(
                PassthroughUnknowableMacroDiagnostic
                    .requiresStruct
                    .diagnose(at: decl)
            )
            return nil
        }

        // Find the option enum within the enum.
        let knownCasesEnums: [EnumDeclSyntax] = decl.memberBlock.members.compactMap({ member in
            if let enumDecl = member.decl.as(EnumDeclSyntax.self),
               enumDecl.name.text == knownCasesEnumName {
                return enumDecl
            }

            return nil
        })

        guard let knownCasesEnum = knownCasesEnums.first else {
            context.diagnose(
                PassthroughUnknowableMacroDiagnostic
                    .requiresKnownCasesEnum(knownCasesEnumName)
                    .diagnose(at: decl)
            )
            return nil
        }

        // Retrieve the raw type from the known cases enum.
        // For an enum with a raw type, the raw type is always the first in the list of inherited types.
        guard let rawType = knownCasesEnum.inheritanceClause?.inheritedTypes.first?.type else {
            context.diagnose(
                PassthroughUnknowableMacroDiagnostic
                    .requiresKnownCasesEnumRawType
                    .diagnose(at: attribute)
            )
            return nil
        }

        return (enumDecl, knownCasesEnum, rawType)
    }
}

extension PassthroughUnknowableMacro: ExtensionMacro {
    public static func expansion(
        of attribute: AttributeSyntax,
        attachedTo decl: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // If there is an explicit conformance to PassthroughUnknowable already, don't add one.
        if protocols.isEmpty {
            return []
        }

        let ext: DeclSyntax = "extension \(type.trimmed): PassthroughUnknowable {}"

        return [ext.cast(ExtensionDeclSyntax.self)]
    }
}

extension PassthroughUnknowableMacro: MemberMacro {
    public static func expansion<
        Decl: DeclGroupSyntax,
        Context: MacroExpansionContext
    >(
        of attribute: AttributeSyntax,
        providingMembersOf decl: Decl,
        in context: Context
    ) throws -> [DeclSyntax] {
        // Decode the expansion arguments.
        guard let (_, knownCasesEnum, rawType) = decodeExpansion(of: attribute, attachedTo: decl, in: context) else {
            return []
        }

        // Find all of the case elements.
        var caseElements: [EnumCaseElementSyntax] = []
        for member in knownCasesEnum.memberBlock.members {
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                caseElements.append(contentsOf: caseDecl.elements)
            }
        }

        // Dig out the access control keyword we need.
        let access = decl.modifiers.first(where: \.isNeededAccessLevelModifier)

        // Make our own cases corresponding to the known cases.
        let passthroughCases = caseElements.map { (element) -> DeclSyntax in
            "case \(element.name)"
        }

        // HACK: without the semicolons, each switch case gets appended directly to the front of the next one.
        //  The example for this constructor does not imply such a thing would be necessary.

        let initSwitch = try SwitchExprSyntax("switch rawValue") {
            for element in caseElements {
                SwitchCaseSyntax("case \(knownCasesEnum.name).\(element.name).rawValue: self = .\(element.name);")
            }
            SwitchCaseSyntax("default: self = .unknown(rawValue)")
        }

        let rawValueSwitch = try SwitchExprSyntax("switch self") {
            for element in caseElements {
                SwitchCaseSyntax("case .\(element.name): \(knownCasesEnum.name).\(element.name).rawValue;")
            }
            SwitchCaseSyntax("case let .unknown(rawValue): rawValue")
        }

        let knownCasesArray = ArrayExprSyntax(expressions: caseElements.map { element in
            ".\(element.name)"
        })

        return [
            "\(access)typealias RawValue = \(rawType)",
        ] + passthroughCases + [
            "case unknown(_ rawValue: RawValue)",
            "\(access)init(rawValue: RawValue) { \(initSwitch) }",
            "\(access)var rawValue: RawValue { \(rawValueSwitch) }",
            "\(access)static var knownCases: [Self] { \(knownCasesArray) }",
        ]
    }
}

extension DeclModifierSyntax {
    var isNeededAccessLevelModifier: Bool {
        switch self.name.tokenKind {
        case .keyword(.public): return true
        default: return false
        }
    }
}

extension SyntaxStringInterpolation {
    // It would be nice for SwiftSyntaxBuilder to provide this out-of-the-box.
    mutating func appendInterpolation<Node: SyntaxProtocol>(_ node: Node?) {
        if let node = node {
            appendInterpolation(node)
        }
    }
}
