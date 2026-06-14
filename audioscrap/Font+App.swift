import SwiftUI
import AppKit

extension Font {
    /// Returns a `Font` using the bundled preferred font for the given `TextStyle`.
    /// Falls back to system sizes when a mapping isn't available.
    static func appFont(_ textStyle: Font.TextStyle) -> Font {
        let size: CGFloat
        switch textStyle {
        case .largeTitle:
            size = 34
        case .title:
            size = 28
        case .title2:
            size = 22
        case .title3:
            size = 20
        case .headline:
            size = 17
        case .subheadline:
            size = 15
        case .callout:
            size = 16
        case .body:
            size = 17
        case .footnote:
            size = 13
        case .caption:
            size = 12
        case .caption2:
            size = 11
        default:
            size = NSFont.systemFontSize
        }

        return Font.custom(FontManager.preferredFontPostScriptName, size: size)
    }

    /// Returns a `Font` using the bundled preferred font at a specific point size.
    static func appFont(size: CGFloat) -> Font {
        return Font.custom(FontManager.preferredFontPostScriptName, size: size)
    }
}
