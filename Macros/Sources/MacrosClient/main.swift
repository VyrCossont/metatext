import Macros

let a = 17
let b = 25

let (result, code) = #stringify(a + b)

print("The value \(result) was produced by the code \"\(code)\"")

@PassthroughUnknowable
enum Bricks {
    private enum KnownCases: String {
        case mud
        case clay
    }
}

print("List of bricks:")
for brick in Bricks.knownCases {
    print("- \(brick)")
}
