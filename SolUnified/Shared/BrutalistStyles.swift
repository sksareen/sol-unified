//
//  BrutalistStyles.swift
//  SolUnified
//
//  Brutalist design system and reusable styles
//

import SwiftUI

// MARK: - Colors
extension Color {
    static var brutalistBgPrimary: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#0a0a0a") : Color(hex: "#fafafa")
    }
    
    static var brutalistBgSecondary: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#18181b") : Color(hex: "#ffffff")
    }
    
    static var brutalistBgTertiary: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#27272a") : Color(hex: "#f4f4f5")
    }
    
    static var brutalistTextPrimary: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#fafafa") : Color(hex: "#18181b")
    }
    
    static var brutalistTextSecondary: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#a1a1aa") : Color(hex: "#52525b")
    }
    
    static var brutalistTextMuted: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#71717a") : Color(hex: "#a1a1aa")
    }
    
    static var brutalistBorder: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#3f3f46") : Color(hex: "#e4e4e7")
    }
    
    static var brutalistAccent: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#60a5fa") : Color(hex: "#3b82f6")
    }
    
    static var brutalistAccentHover: Color {
        AppSettings.shared.isDarkMode ? Color(hex: "#3b82f6") : Color(hex: "#2563eb")
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
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// MARK: - Line Spacing
struct LineSpacing {
    static let compact: CGFloat = 1.2
    static let normal: CGFloat = 1.5
    static let comfortable: CGFloat = 1.8
}

// MARK: - Border Radius
struct BorderRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
}

// MARK: - Typography
struct Typography {
    static let headingSize: CGFloat = 18
    static let bodySize: CGFloat = 14
    static let smallSize: CGFloat = 12
    static let lineHeight: CGFloat = 1.5
}

// MARK: - Button Styles
struct BrutalistButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.brutalistBgSecondary)
            .foregroundColor(Color.brutalistTextSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: BorderRadius.sm)
                    .stroke(Color.brutalistBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
}

struct BrutalistPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(configuration.isPressed ? Color.brutalistAccentHover : Color.brutalistAccent)
            .foregroundColor(.white)
            .cornerRadius(BorderRadius.sm)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
}

struct BrutalistSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.brutalistBgTertiary)
            .foregroundColor(Color.brutalistTextMuted)
            .overlay(
                RoundedRectangle(cornerRadius: BorderRadius.sm)
                    .stroke(Color.brutalistBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Card Style
struct BrutalistCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.lg)
            .background(Color.brutalistBgSecondary)
            .cornerRadius(BorderRadius.md)
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
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

