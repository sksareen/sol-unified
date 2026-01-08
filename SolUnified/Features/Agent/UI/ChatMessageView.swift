//
//  ChatMessageView.swift
//  SolUnified
//
//  Renders individual chat messages
//

import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer()
                userMessageView
            } else if message.role == .assistant {
                assistantMessageView
                Spacer()
            } else if message.role == .tool {
                toolResultView
            }
        }
    }

    // MARK: - User Message

    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.brutalistAccent)
                .cornerRadius(16)
                .cornerRadius(4, corners: [.bottomRight])

            Text(formatTime(message.timestamp))
                .font(.system(size: 10))
                .foregroundColor(Color.brutalistTextSecondary.opacity(0.7))
        }
        .frame(maxWidth: 400, alignment: .trailing)
    }

    // MARK: - Assistant Message

    private var assistantMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Avatar
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "brain")
                    .font(.system(size: 14))
                    .foregroundColor(Color.brutalistAccent)
                    .frame(width: 28, height: 28)
                    .background(Color.brutalistAccent.opacity(0.15))
                    .cornerRadius(14)

                VStack(alignment: .leading, spacing: 4) {
                    // Main content
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.system(size: 14))
                            .foregroundColor(Color.brutalistTextPrimary)
                            .textSelection(.enabled)
                    }

                    // Tool calls
                    if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                        toolCallsView(toolCalls)
                    }

                    // Timestamp
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(Color.brutalistTextSecondary.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: 500, alignment: .leading)
    }

    // MARK: - Tool Calls

    private func toolCallsView(_ toolCalls: [ToolCall]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(toolCalls) { call in
                HStack(spacing: 8) {
                    Image(systemName: iconForTool(call.toolName))
                        .font(.system(size: 12))
                        .foregroundColor(Color.brutalistAccent)

                    Text(displayNameForTool(call.toolName))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(Color.brutalistTextSecondary.opacity(0.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.brutalistBgSecondary)
                .cornerRadius(6)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Tool Results

    private var toolResultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let results = message.toolResults {
                ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(result.success ? .green : .red)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.success ? "Tool executed" : "Tool failed")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.brutalistTextSecondary)

                            if let preview = resultPreview(result.result) {
                                Text(preview)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.brutalistTextSecondary.opacity(0.7))
                                    .lineLimit(3)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.brutalistBgSecondary.opacity(0.5))
                    .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: 500, alignment: .leading)
        .padding(.leading, 38)  // Align with assistant messages
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func iconForTool(_ toolName: String) -> String {
        guard let tool = AgentTool(rawValue: toolName) else {
            return "wrench.fill"
        }

        switch tool {
        case .lookupContact: return "person.fill"
        case .searchMemory: return "brain"
        case .checkCalendar: return "calendar"
        case .createCalendarEvent: return "calendar.badge.plus"
        case .sendEmail: return "envelope.fill"
        case .searchContext: return "magnifyingglass"
        case .saveMemory: return "square.and.arrow.down.fill"
        }
    }

    private func displayNameForTool(_ toolName: String) -> String {
        guard let tool = AgentTool(rawValue: toolName) else {
            return toolName
        }
        return tool.displayName
    }

    private func resultPreview(_ result: String) -> String? {
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Try to extract meaningful preview
        if let found = json["found"] as? Bool, !found {
            return json["message"] as? String
        }

        if let count = json["count"] as? Int {
            return "\(count) results found"
        }

        if let success = json["success"] as? Bool, success {
            if let message = json["message"] as? String {
                return message
            }
            return "Operation completed"
        }

        if let error = json["error"] as? String {
            return "Error: \(error)"
        }

        return nil
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = NSBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// macOS compatibility
extension NSBezierPath {
    convenience init(roundedRect rect: CGRect, byRoundingCorners corners: UIRectCorner, cornerRadii: CGSize) {
        self.init()

        let topLeft = corners.contains(.topLeft) ? cornerRadii.width : 0
        let topRight = corners.contains(.topRight) ? cornerRadii.width : 0
        let bottomLeft = corners.contains(.bottomLeft) ? cornerRadii.width : 0
        let bottomRight = corners.contains(.bottomRight) ? cornerRadii.width : 0

        move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        line(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))

        if topRight > 0 {
            appendArc(withCenter: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                      radius: topRight, startAngle: -90, endAngle: 0, clockwise: false)
        }

        line(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))

        if bottomRight > 0 {
            appendArc(withCenter: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                      radius: bottomRight, startAngle: 0, endAngle: 90, clockwise: false)
        }

        line(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))

        if bottomLeft > 0 {
            appendArc(withCenter: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                      radius: bottomLeft, startAngle: 90, endAngle: 180, clockwise: false)
        }

        line(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))

        if topLeft > 0 {
            appendArc(withCenter: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                      radius: topLeft, startAngle: 180, endAngle: 270, clockwise: false)
        }

        close()
    }

    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)

            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}

struct UIRectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = UIRectCorner(rawValue: 1 << 0)
    static let topRight = UIRectCorner(rawValue: 1 << 1)
    static let bottomLeft = UIRectCorner(rawValue: 1 << 2)
    static let bottomRight = UIRectCorner(rawValue: 1 << 3)
    static let allCorners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

#Preview {
    VStack(spacing: 16) {
        ChatMessageView(message: ChatMessage(role: .user, content: "Schedule coffee with Sarah next week"))
        ChatMessageView(message: ChatMessage(role: .assistant, content: "I'll help you schedule coffee with Sarah. Let me check your calendar and look up Sarah's contact information."))
    }
    .padding()
    .frame(width: 600)
}
