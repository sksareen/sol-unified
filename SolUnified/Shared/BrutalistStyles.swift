//
//  BrutalistStyles.swift
//  SolUnified
//
//  Brutalist design system and reusable styles
//

import SwiftUI

// MARK: - Visual Effect View for macOS Vibrancy
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Colors
extension Color {
    static var brutalistBgPrimary: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#050505") : Color(hex: "#fafafa")
    }
    
    static var brutalistBgSecondary: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#0D0D0D") : Color(hex: "#ffffff")
    }
    
    static var brutalistBgTertiary: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#1A1A1A") : Color(hex: "#f4f4f5")
    }
    
    static var brutalistTextPrimary: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#FFFFFF") : Color(hex: "#18181b")
    }
    
    static var brutalistTextSecondary: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#8E8E93") : Color(hex: "#52525b")
    }
    
    static var brutalistTextMuted: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#48484A") : Color(hex: "#a1a1aa")
    }
    
    static var brutalistBorder: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#1C1C1E") : Color(hex: "#e4e4e7")
    }
    
    static var brutalistAccent: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#0A84FF") : Color(hex: "#3b82f6")
    }
    
    static var brutalistAccentHover: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#409CFF") : Color(hex: "#2563eb")
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Spacing
struct Spacing {
    static let xs: CGFloat = 2
    static let sm: CGFloat = 6
    static let md: CGFloat = 12
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}

// MARK: - Line Spacing
struct LineSpacing {
    static let compact: CGFloat = 1.1
    static let normal: CGFloat = 1.4
    static let comfortable: CGFloat = 1.6
}

// MARK: - Border Radius
struct BorderRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 15  // Mac-like window radius
    static let lg: CGFloat = 12
}

// MARK: - Typography
struct Typography {
    static let headingSize: CGFloat = 16
    static let bodySize: CGFloat = 12
    static let smallSize: CGFloat = 10
    static let lineHeight: CGFloat = 1.4
}

// MARK: - Button Styles
struct BrutalistButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.brutalistBgTertiary)
            .foregroundColor(Color.brutalistTextPrimary)
            .cornerRadius(6)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct BrutalistPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Color.brutalistAccentHover : Color.brutalistAccent)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct BrutalistSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brutalistBgTertiary)
            .foregroundColor(Color.brutalistTextSecondary)
            .cornerRadius(6)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Card Style
struct BrutalistCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.brutalistBgSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brutalistBorder, lineWidth: 1)
            )
    }
}

extension View {
    func brutalistCard() -> some View {
        modifier(BrutalistCardModifier())
    }
}

// MARK: - Text Field Style
struct BrutalistTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(Spacing.md)
            .background(Color.brutalistBgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: BorderRadius.sm)
                    .stroke(Color.brutalistBorder, lineWidth: 1)
            )
            .font(.system(size: Typography.bodySize))
    }
}

