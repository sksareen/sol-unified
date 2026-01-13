//
//  PeopleGraphView.swift
//  SolUnified
//
//  Force-directed graph visualization for people network
//

import SwiftUI

struct PeopleGraphView: View {
    @StateObject private var store = PeopleStore.shared
    @Binding var selectedPerson: Person?

    @State private var nodes: [PersonGraphNode] = []
    @State private var edges: [PersonGraphEdge] = []
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var draggedNodeId: String?
    @State private var isSimulating = true

    // Physics constants
    private let repulsionForce: CGFloat = 8000
    private let attractionForce: CGFloat = 0.008
    private let damping: CGFloat = 0.85
    private let idealEdgeLength: CGFloat = 180
    private let simulationSteps = 100

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.brutalistBgPrimary

                // Graph canvas
                Canvas { context, size in
                    let transform = CGAffineTransform(translationX: offset.width + size.width/2, y: offset.height + size.height/2)
                        .scaledBy(x: scale, y: scale)

                    // Draw edges first (behind nodes)
                    for edge in edges {
                        guard let sourceNode = nodes.first(where: { $0.id == edge.sourceId }),
                              let targetNode = nodes.first(where: { $0.id == edge.targetId }) else { continue }

                        var path = Path()
                        let start = sourceNode.position.applying(transform)
                        let end = targetNode.position.applying(transform)
                        path.move(to: start)
                        path.addLine(to: end)

                        context.stroke(path, with: .color(edge.color), lineWidth: 1.5)
                    }

                    // Draw nodes
                    for node in nodes {
                        let pos = node.position.applying(transform)
                        let nodeRadius = node.radius * scale
                        let rect = CGRect(
                            x: pos.x - nodeRadius,
                            y: pos.y - nodeRadius,
                            width: nodeRadius * 2,
                            height: nodeRadius * 2
                        )

                        // Node circle
                        let isSelected = selectedPerson?.id == node.id
                        let color = isSelected ? Color.brutalistAccent : node.color
                        context.fill(Circle().path(in: rect), with: .color(color))

                        // Border for selected
                        if isSelected {
                            context.stroke(Circle().path(in: rect), with: .color(.white), lineWidth: 2)
                        }
                    }

                    // Draw labels (on top)
                    for node in nodes {
                        let pos = node.position.applying(transform)
                        let nodeRadius = node.radius * scale

                        // Only show labels when zoomed in enough
                        if scale > 0.5 {
                            let firstName = node.person.name.components(separatedBy: " ").first ?? node.person.name
                            let labelPos = CGPoint(x: pos.x, y: pos.y + nodeRadius + 12)

                            context.draw(
                                Text(firstName)
                                    .font(.system(size: max(9, 11 * scale), weight: .medium))
                                    .foregroundColor(.brutalistTextSecondary),
                                at: labelPos
                            )
                        }
                    }
                }
                .gesture(magnificationGesture)
                .gesture(panGesture)
                .onTapGesture { location in
                    handleTap(at: location, in: geometry.size)
                }

                // Controls overlay
                VStack {
                    HStack {
                        Spacer()
                        controlsPanel
                    }
                    Spacer()
                    legendPanel
                }
                .padding()
            }
        }
        .onAppear {
            initializeGraph()
            runSimulation()
        }
    }

    // MARK: - Controls

    private var controlsPanel: some View {
        VStack(spacing: 8) {
            Button(action: { scale = min(scale * 1.2, 3.0) }) {
                Image(systemName: "plus.magnifyingglass")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(GraphControlButtonStyle())

            Button(action: { scale = max(scale / 1.2, 0.2) }) {
                Image(systemName: "minus.magnifyingglass")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(GraphControlButtonStyle())

            Button(action: resetView) {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(GraphControlButtonStyle())

            Button(action: { runSimulation() }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(GraphControlButtonStyle())
        }
        .padding(8)
        .background(Color.brutalistBgSecondary.opacity(0.9))
        .cornerRadius(8)
    }

    private var legendPanel: some View {
        HStack(spacing: 16) {
            ForEach(ConnectionType.allCases, id: \.self) { type in
                HStack(spacing: 4) {
                    Circle()
                        .fill(type.color)
                        .frame(width: 8, height: 8)
                    Text(type.displayName)
                        .font(.system(size: 10))
                        .foregroundColor(.brutalistTextMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.brutalistBgSecondary.opacity(0.9))
        .cornerRadius(6)
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(0.2, min(3.0, value))
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: offset.width + value.translation.width / 10,
                    height: offset.height + value.translation.height / 10
                )
            }
    }

    // MARK: - Graph Logic

    private func initializeGraph() {
        let data = store.getGraphData()
        nodes = data.nodes
        edges = data.edges

        // Center the graph
        offset = .zero
        scale = 1.0
    }

    private func runSimulation() {
        // Run physics simulation for a fixed number of steps
        for _ in 0..<simulationSteps {
            simulateStep()
        }
    }

    private func simulateStep() {
        guard nodes.count > 1 else { return }

        for i in 0..<nodes.count {
            guard !nodes[i].isFixed else { continue }

            var force = CGPoint.zero

            // Center gravity (weak pull toward center)
            let centerForce: CGFloat = 0.01
            force.x -= nodes[i].position.x * centerForce
            force.y -= nodes[i].position.y * centerForce

            // Repulsion from other nodes
            for j in 0..<nodes.count where i != j {
                let diff = CGPoint(
                    x: nodes[i].position.x - nodes[j].position.x,
                    y: nodes[i].position.y - nodes[j].position.y
                )
                let distance = max(sqrt(diff.x * diff.x + diff.y * diff.y), 1)
                let repulsion = repulsionForce / (distance * distance)
                force.x += (diff.x / distance) * repulsion
                force.y += (diff.y / distance) * repulsion
            }

            // Attraction along edges
            for edge in edges {
                let otherId: String?
                if edge.sourceId == nodes[i].id {
                    otherId = edge.targetId
                } else if edge.targetId == nodes[i].id {
                    otherId = edge.sourceId
                } else {
                    otherId = nil
                }

                if let otherId = otherId,
                   let otherIndex = nodes.firstIndex(where: { $0.id == otherId }) {
                    let diff = CGPoint(
                        x: nodes[otherIndex].position.x - nodes[i].position.x,
                        y: nodes[otherIndex].position.y - nodes[i].position.y
                    )
                    let distance = sqrt(diff.x * diff.x + diff.y * diff.y)
                    if distance > 0 {
                        let displacement = distance - idealEdgeLength
                        force.x += (diff.x / distance) * displacement * attractionForce
                        force.y += (diff.y / distance) * displacement * attractionForce
                    }
                }
            }

            // Update velocity and position
            nodes[i].velocity.x = (nodes[i].velocity.x + force.x) * damping
            nodes[i].velocity.y = (nodes[i].velocity.y + force.y) * damping
            nodes[i].position.x += nodes[i].velocity.x
            nodes[i].position.y += nodes[i].velocity.y
        }
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        let adjustedLocation = CGPoint(
            x: (location.x - size.width/2 - offset.width) / scale,
            y: (location.y - size.height/2 - offset.height) / scale
        )

        for node in nodes {
            let distance = sqrt(
                pow(adjustedLocation.x - node.position.x, 2) +
                pow(adjustedLocation.y - node.position.y, 2)
            )
            if distance < node.radius {
                selectedPerson = node.person
                return
            }
        }

        // Clicked empty space - deselect
        selectedPerson = nil
    }

    private func resetView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            scale = 1.0
            offset = .zero
        }
        initializeGraph()
        runSimulation()
    }
}

// MARK: - Button Style

struct GraphControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.brutalistTextPrimary)
            .background(configuration.isPressed ? Color.brutalistBgTertiary : Color.clear)
            .cornerRadius(6)
    }
}

// MARK: - Preview

#if DEBUG
struct PeopleGraphView_Previews: PreviewProvider {
    static var previews: some View {
        PeopleGraphView(selectedPerson: .constant(nil))
            .frame(width: 800, height: 600)
    }
}
#endif
