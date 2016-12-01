//
//  TrailingCommaRule.swift
//  SwiftLint
//
//  Created by Marcelo Fabri on 21/11/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct TrailingCommaRule: ASTRule, ConfigurationProviderRule {
    public var configuration = TrailingCommaConfiguration()

    public init() {}

    public static let description = RuleDescription(
        identifier: "trailing_comma",
        name: "Trailing Comma",
        description: "Trailing commas in arrays and dictionaries should be avoided/enforced.",
        nonTriggeringExamples: [
            "let foo = [1, 2, 3]\n",
            "let foo = []\n",
            "let foo = [:]\n",
            "let foo = [1: 2, 2: 3]\n",
            "let foo = [Void]()\n"
        ],
        triggeringExamples: [
            "let foo = [1, 2, 3↓,]\n",
            "let foo = [1, 2, 3↓, ]\n",
            "let foo = [1, 2, 3   ↓,]\n",
            "let foo = [1: 2, 2: 3↓, ]\n",
            "struct Bar {\n let foo = [1: 2, 2: 3↓, ]\n}\n",
            "let foo = [1, 2, 3↓,] + [4, 5, 6↓,]\n"
        ]
    )

    public func validateFile(file: File,
                             kind: SwiftExpressionKind,
                             dictionary: [String: SourceKitRepresentable]) -> [StyleViolation] {

        let allowedKinds: [SwiftExpressionKind] = [.Array, .Dictionary]

        guard let bodyOffset = (dictionary["key.bodyoffset"] as? Int64).flatMap({ Int($0) }),
            bodyLength = (dictionary["key.bodylength"] as? Int64).flatMap({ Int($0) }),
            elements = dictionary["key.elements"]  as? [SourceKitRepresentable]
            where allowedKinds.contains(kind) else {
                return []
        }

        let endPositions = elements.flatMap { element -> Int? in
            guard let dictionary = element as? [String: SourceKitRepresentable],
                offset = (dictionary["key.offset"] as? Int64).flatMap({ Int($0) }),
                length = (dictionary["key.length"] as? Int64).flatMap({ Int($0) }) else {
                    return nil
            }

            return offset + length
        }

        guard let lastPosition = endPositions.maxElement() else {
            return []
        }

        if let (startLine, _) =  file.contents.lineAndCharacterForByteOffset(bodyOffset),
            (endLine, _) =  file.contents.lineAndCharacterForByteOffset(lastPosition)
            where configuration.mandatoryComma && startLine == endLine {
            // shouldn't trigger if mandatory comma style and is a single-line declaration 
            return []
        }

        let length = bodyLength + bodyOffset - lastPosition
        let contentsAfterLastElement = file.contents
            .substringWithByteRange(start: lastPosition, length: length) ?? ""

        // if a trailing comma is not present
        guard let commaIndex = contentsAfterLastElement.lastIndexOf(",") else {
            guard configuration.mandatoryComma else {
                return []
            }

            return violations(file, byteOffset: lastPosition)
        }

        // trailing comma is present, which is a violation if mandatoryComma is false
        guard !configuration.mandatoryComma else {
            return []
        }

        let violationOffset = lastPosition + commaIndex
        return violations(file, byteOffset: violationOffset)
    }

    private func violations(file: File, byteOffset: Int) -> [StyleViolation] {
        return [
            StyleViolation(ruleDescription: self.dynamicType.description,
                severity: configuration.severityConfiguration.severity,
                location: Location(file: file, byteOffset: byteOffset)
            )
        ]
    }
}

public enum SwiftExpressionKind: String {
    case Array = "source.lang.swift.expr.array"
    case Dictionary = "source.lang.swift.expr.dictionary"
    case Other

    public init?(rawValue: String) {
        switch rawValue {
        case Array.rawValue:
            self = .Array
        case Dictionary.rawValue:
            self = .Dictionary
        default:
            self = .Other
        }
    }
}
