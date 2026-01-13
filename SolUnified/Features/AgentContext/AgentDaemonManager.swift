//
//  AgentDaemonManager.swift
//  SolUnified
//
//  Manages the Python agent daemon as a subprocess
//

import Foundation
import AppKit

@MainActor
class AgentDaemonManager: ObservableObject {
    static let shared = AgentDaemonManager()

    // MARK: - Published State

    @Published var isRunning = false
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "agentDaemonEnabled")
            if isEnabled {
                start()
            } else {
                stop()
            }
        }
    }
    @Published var lastCheckTime: Date?
    @Published var statusMessage = "Not running"
    @Published var meetingsPreparedToday = 0
    @Published var lastError: String?

    // MARK: - Private

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var logBuffer: [String] = []
    private let maxLogLines = 100

    private let pythonPath: String
    private let agentModulePath: String

    // MARK: - Init

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "agentDaemonEnabled")

        // Find Python path
        self.pythonPath = AgentDaemonManager.findPython() ?? "/usr/bin/python3"

        // Agent module path - find the project root
        // When running from .build/Sol Unified.app, we need to go up to find agent/sdk
        let bundlePath = Bundle.main.bundlePath

        // Try multiple possible locations
        let possibleRoots = [
            // Development: .build/Sol Unified.app -> go up 2 levels to project root
            (bundlePath as NSString).deletingLastPathComponent,
            // Development: .build/Sol Unified.app/Contents/MacOS -> go up 4 levels
            ((((bundlePath as NSString).deletingLastPathComponent as NSString)
                .deletingLastPathComponent as NSString)
                .deletingLastPathComponent as NSString)
                .deletingLastPathComponent,
            // Hardcoded fallback for this project
            "/Users/savarsareen/coding/mable/sol-unified",
        ]

        var foundPath: String? = nil
        for root in possibleRoots {
            let agentPath = (root as NSString).appendingPathComponent("agent/sdk/main.py")
            if FileManager.default.fileExists(atPath: agentPath) {
                foundPath = root
                break
            }
        }

        self.agentModulePath = foundPath ?? possibleRoots.last!

        print("🤖 Agent daemon manager initialized")
        print("   Python: \(pythonPath)")
        print("   Agent path: \(agentModulePath)")
        print("   Agent main.py exists: \(FileManager.default.fileExists(atPath: (agentModulePath as NSString).appendingPathComponent("agent/sdk/main.py")))")
    }

    // MARK: - Python Discovery

    private static func findPython() -> String? {
        // Try common locations
        let candidates = [
            "/opt/homebrew/bin/python3",      // Apple Silicon Homebrew
            "/usr/local/bin/python3",         // Intel Homebrew
            "/usr/bin/python3",               // System Python
            "\(NSHomeDirectory())/.pyenv/shims/python3",  // pyenv
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try which command
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["python3"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            print("⚠️ Could not find python3: \(error)")
        }

        return nil
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else {
            print("🤖 Agent daemon already running")
            return
        }

        guard FileManager.default.isExecutableFile(atPath: pythonPath) else {
            lastError = "Python not found at \(pythonPath)"
            statusMessage = "Error: Python not found"
            print("❌ \(lastError!)")
            return
        }

        // Check if agent module exists
        let mainPyPath = (agentModulePath as NSString).appendingPathComponent("agent/sdk/main.py")
        guard FileManager.default.fileExists(atPath: mainPyPath) else {
            lastError = "Agent module not found at \(mainPyPath)"
            statusMessage = "Error: Agent not installed"
            print("❌ \(lastError!)")
            return
        }

        print("🤖 Starting agent daemon...")
        print("   Python: \(pythonPath)")
        print("   PYTHONPATH: \(agentModulePath)")

        process = Process()
        process?.executableURL = URL(fileURLWithPath: pythonPath)
        process?.arguments = ["-m", "agent.sdk.main", "daemon"]
        process?.currentDirectoryURL = URL(fileURLWithPath: agentModulePath)

        // Set up environment - start fresh to avoid issues
        var env: [String: String] = [:]
        env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin"
        env["HOME"] = NSHomeDirectory()
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONPATH"] = agentModulePath
        if let apiKey = UserDefaults.standard.string(forKey: "claudeAPIKey"), !apiKey.isEmpty {
            env["ANTHROPIC_API_KEY"] = apiKey
        }
        process?.environment = env

        // Set up pipes for output
        outputPipe = Pipe()
        errorPipe = Pipe()
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe

        // Handle output
        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    self?.handleOutput(output)
                }
            }
        }

        errorPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    self?.handleError(output)
                }
            }
        }

        // Handle termination
        process?.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.handleTermination(exitCode: process.terminationStatus)
            }
        }

        do {
            try process?.run()
            isRunning = true
            lastError = nil
            statusMessage = "Running"
            print("✅ Agent daemon started (PID: \(process?.processIdentifier ?? 0))")
        } catch {
            lastError = "Failed to start: \(error.localizedDescription)"
            statusMessage = "Error: \(error.localizedDescription)"
            print("❌ Failed to start agent daemon: \(error)")
        }
    }

    func stop() {
        guard isRunning, let process = process else {
            print("🤖 Agent daemon not running")
            return
        }

        print("🤖 Stopping agent daemon...")

        // Send interrupt signal first (graceful shutdown)
        process.interrupt()

        // Give it a moment to shut down gracefully
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
            if process.isRunning {
                print("🤖 Force terminating agent daemon...")
                process.terminate()
            }
            DispatchQueue.main.async {
                self?.cleanup()
            }
        }
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.start()
        }
    }

    private func cleanup() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        errorPipe = nil
        process = nil
        isRunning = false
        statusMessage = "Stopped"
    }

    // MARK: - Output Handling

    private func handleOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

        for line in lines {
            print("🤖 [agent] \(line)")
            addToLog(line)

            // Parse status updates
            if line.contains("Checking for meetings") {
                lastCheckTime = Date()
            }
            if line.contains("Created action:") {
                meetingsPreparedToday += 1
            }
        }
    }

    private func handleError(_ output: String) {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

        for line in lines {
            print("🤖 [agent error] \(line)")
            addToLog("[ERROR] \(line)")

            // Check for specific errors
            if line.contains("ModuleNotFoundError") {
                lastError = "Python dependencies not installed"
                statusMessage = "Error: Missing dependencies"
            } else if line.contains("ANTHROPIC_API_KEY") {
                lastError = "Anthropic API key not set"
                statusMessage = "Error: API key missing"
            }
        }
    }

    private func handleTermination(exitCode: Int32) {
        print("🤖 Agent daemon terminated with exit code: \(exitCode)")
        cleanup()

        if exitCode != 0 && isEnabled {
            // Unexpected termination - don't auto-restart to avoid loops
            lastError = "Process exited with code \(exitCode). Check logs."
            statusMessage = "Stopped (exit code \(exitCode))"
            print("🤖 Agent daemon crashed. Manual restart required.")
        }
    }

    private func addToLog(_ line: String) {
        logBuffer.append("[\(ISO8601DateFormatter().string(from: Date()))] \(line)")
        if logBuffer.count > maxLogLines {
            logBuffer.removeFirst()
        }
    }

    // MARK: - Public Queries

    var recentLogs: [String] {
        Array(logBuffer.suffix(20))
    }

    var statusSummary: String {
        if !isEnabled {
            return "Disabled"
        }
        if !isRunning {
            return lastError ?? "Not running"
        }
        if let lastCheck = lastCheckTime {
            let ago = Int(-lastCheck.timeIntervalSinceNow / 60)
            return "Running • Last check \(ago)m ago"
        }
        return "Running"
    }

    // MARK: - Auto-start

    func autoStartIfEnabled() {
        if isEnabled {
            print("🤖 Auto-starting agent daemon...")
            start()
        }
    }
}
