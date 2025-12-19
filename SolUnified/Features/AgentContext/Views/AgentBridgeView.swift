import SwiftUI

struct AgentBridgeView: View {
    let bridge: AgentBridge?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let bridge = bridge {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Shared Knowledge Section
                        if let knowledge = bridge.shared_knowledge {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 10))
                                    Text("SHARED CONTEXT")
                                        .font(.system(size: 10, weight: .black))
                                        .tracking(1)
                                }
                                .foregroundColor(.secondary.opacity(0.8))
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    if let findings = knowledge.research_findings {
                                        ForEach(findings, id: \.self) { finding in
                                            KnowledgeRow(text: finding, color: Color(hex: "3B82F6"))
                                        }
                                    }
                                    
                                    if let opportunities = knowledge.product_opportunities {
                                        ForEach(opportunities, id: \.self) { opp in
                                            KnowledgeRow(text: opp, color: Color(hex: "F97316"))
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.brutalistBgSecondary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.brutalistBorder, lineWidth: 1)
                            )
                        }
                        
                        // Active Messages
                        VStack(spacing: 16) {
                            if let msgToJosh = bridge.message_to_josh {
                                MessageBubble(message: msgToJosh, isFromLeft: true)
                            }
                            
                            if let msgToGunter = bridge.message_to_gunter {
                                MessageBubble(message: msgToGunter, isFromLeft: false)
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.3))
                        Text("No bridge data found")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .background(Color.brutalistBgPrimary)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct KnowledgeRow: View {
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineSpacing(4)
                .foregroundColor(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MessageBubble: View {
    let message: AgentMessage
    let isFromLeft: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isFromLeft { Spacer() }
            
            VStack(alignment: isFromLeft ? .leading : .trailing, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isFromLeft ? Color.brutalistBgTertiary : Color.brutalistAccent)
                    .foregroundColor(isFromLeft ? .primary : .white)
                    .cornerRadius(16, corners: isFromLeft ? [.topLeft, .topRight, .bottomRight] : [.topLeft, .topRight, .bottomLeft])
                
                if let action = message.action_requested {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                        Text(action.uppercased())
                            .font(.system(size: 9, weight: .black))
                    }
                    .foregroundColor(isFromLeft ? Color.brutalistAccent : .secondary)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: 280, alignment: isFromLeft ? .leading : .trailing)
            
            if isFromLeft { Spacer() }
        }
    }
}

// Helper for selective rounded corners
struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = NSBezierPath()
        
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0
        
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.curve(to: CGPoint(x: rect.maxX, y: rect.minY + topRight), controlPoint1: CGPoint(x: rect.maxX, y: rect.minY), controlPoint2: CGPoint(x: rect.maxX, y: rect.minY))
        
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.curve(to: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY), controlPoint1: CGPoint(x: rect.maxX, y: rect.maxY), controlPoint2: CGPoint(x: rect.maxX, y: rect.maxY))
        
        path.line(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.curve(to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft), controlPoint1: CGPoint(x: rect.minX, y: rect.maxY), controlPoint2: CGPoint(x: rect.minX, y: rect.maxY))
        
        path.line(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.curve(to: CGPoint(x: rect.minX + topLeft, y: rect.minY), controlPoint1: CGPoint(x: rect.minX, y: rect.minY), controlPoint2: CGPoint(x: rect.minX, y: rect.minY))
        
        path.close()
        return Path(path.cgPath)
    }
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0 ..< self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            @unknown default:
                break
            }
        }
        return path
    }
}

