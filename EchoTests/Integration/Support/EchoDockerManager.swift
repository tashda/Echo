import Foundation

/// Shared Docker container lifecycle management for Echo integration tests.
/// Handles finding Docker, running containers, and waiting for readiness.
final class EchoDockerManager: @unchecked Sendable {

    enum Engine: String {
        case mssql
        case postgres
    }

    struct ContainerConfig {
        let engine: Engine
        let imageTag: String
        let port: Int
        let environmentVariables: [String: String]
        let containerNamePrefix: String
        let readinessCheck: (_ dockerPath: String, _ containerId: String) throws -> Bool
    }

    private let lock = NSLock()
    private var containerId: String?
    private var isStarted = false

    private var containerName: String = ""
    private var dockerPath: String?

    // MARK: - Docker Discovery

    static func findDockerExecutable() -> String? {
        let paths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker",
            "/bin/docker"
        ]
        let fm = FileManager.default
        for path in paths where fm.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    static func verifyDockerRunning(dockerPath: String) throws {
        let process = createProcess(executable: dockerPath, arguments: ["info"])
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw EchoDockerError.dockerNotRunning
        }
    }

    // MARK: - Container Lifecycle

    func startIfNeeded(config: ContainerConfig) throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isStarted else { return }

        guard let docker = Self.findDockerExecutable() else {
            throw EchoDockerError.dockerNotFound
        }
        self.dockerPath = docker
        try Self.verifyDockerRunning(dockerPath: docker)

        let normalized = config.imageTag
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        containerName = "\(config.containerNamePrefix)-\(normalized)-\(config.port)"

        // Check for existing container
        if let existing = try existingContainerID(named: containerName, dockerPath: docker) {
            containerId = existing
            print("♻️ Reusing \(config.engine.rawValue) container \(existing) on port \(config.port)")
        } else {
            try stopContainersByPrefix(config.containerNamePrefix, port: config.port, dockerPath: docker)
            try startFreshContainer(config: config, dockerPath: docker)
        }

        try waitForReady(config: config, dockerPath: docker, maxRetries: 60)
        isStarted = true
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }

        guard let id = containerId, let docker = dockerPath else { return }
        print("🛑 Stopping container \(id)...")
        let process = Self.createProcess(executable: docker, arguments: ["stop", id])
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        containerId = nil
        isStarted = false
    }

    /// Run a shell command inside the container.
    func exec(arguments: [String], input: String? = nil) throws -> (output: String, exitCode: Int32) {
        guard let id = containerId, let docker = dockerPath else {
            throw EchoDockerError.containerNotStarted
        }
        let args = ["exec", "-i", id] + arguments
        let process = Self.createProcess(executable: docker, arguments: args)

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        if let input {
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            try process.run()
            if let data = input.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(data)
            }
            try inputPipe.fileHandleForWriting.close()
        } else {
            try process.run()
        }

        process.waitUntilExit()
        let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (output, process.terminationStatus)
    }

    // MARK: - Private

    private func startFreshContainer(config: ContainerConfig, dockerPath: String) throws {
        print("🚀 Starting \(config.engine.rawValue) \(config.imageTag) on port \(config.port)...")

        let architecture = machineArchitecture()
        let platformArgs = architecture.contains("arm64") || architecture.contains("aarch64")
            ? ["--platform", "linux/amd64"]
            : []

        let portMapping: String
        switch config.engine {
        case .mssql: portMapping = "\(config.port):1433"
        case .postgres: portMapping = "\(config.port):5432"
        }

        var envArgs: [String] = []
        for (key, value) in config.environmentVariables {
            envArgs += ["-e", "\(key)=\(value)"]
        }

        let args = ["run"] + platformArgs + [
            "-d", "--rm",
            "--name", containerName,
            "-p", portMapping
        ] + envArgs + [config.imageTag]

        let process = Self.createProcess(executable: dockerPath, arguments: args)
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 || output.isEmpty {
            let errorOutput = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw EchoDockerError.startFailed(errorOutput)
        }

        containerId = output
        print("📦 Container started: \(output.prefix(12))")
    }

    private func waitForReady(config: ContainerConfig, dockerPath: String, maxRetries: Int) throws {
        print("⏳ Waiting for \(config.engine.rawValue) to be ready...")
        for i in 1...maxRetries {
            if try config.readinessCheck(dockerPath, containerId!) {
                print("✅ \(config.engine.rawValue) ready after \(i)s")
                return
            }
            Thread.sleep(forTimeInterval: 1.0)
        }
        throw EchoDockerError.readinessTimeout(config.engine.rawValue, maxRetries)
    }

    private func existingContainerID(named name: String, dockerPath: String) throws -> String? {
        let process = Self.createProcess(executable: dockerPath, arguments: ["ps", "-aq", "--filter", "name=^\(name)$"])
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let id = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id, !id.isEmpty else { return nil }
        return id
    }

    private func stopContainersByPrefix(_ prefix: String, port: Int, dockerPath: String) throws {
        let process = Self.createProcess(executable: dockerPath, arguments: [
            "ps", "-aq", "--filter", "name=^\(prefix)-"
        ])
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        let ids = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .split(whereSeparator: \.isNewline).map(String.init) ?? []
        for id in ids where !id.isEmpty {
            let stop = Self.createProcess(executable: dockerPath, arguments: ["rm", "-f", id])
            stop.standardOutput = FileHandle.nullDevice
            stop.standardError = FileHandle.nullDevice
            try? stop.run()
            stop.waitUntilExit()
        }
    }

    static func createProcess(executable: String, arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        let dockerDir = (executable as NSString).deletingLastPathComponent
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "\(dockerDir):/usr/local/bin:/opt/homebrew/bin:\(currentPath)"
        process.environment = env
        return process
    }

    private func machineArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = systemInfo.machine
        let machineSize = MemoryLayout.size(ofValue: machine)
        return withUnsafePointer(to: machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: machineSize) {
                String(cString: $0)
            }
        }
    }
}

// MARK: - Errors

enum EchoDockerError: Error, CustomStringConvertible {
    case dockerNotFound
    case dockerNotRunning
    case containerNotStarted
    case startFailed(String)
    case readinessTimeout(String, Int)
    case sqlExecutionFailed(String)

    var description: String {
        switch self {
        case .dockerNotFound: "Docker executable not found"
        case .dockerNotRunning: "Docker Desktop is not running"
        case .containerNotStarted: "Container has not been started"
        case .startFailed(let msg): "Failed to start container: \(msg)"
        case .readinessTimeout(let engine, let seconds): "\(engine) not ready after \(seconds)s"
        case .sqlExecutionFailed(let msg): "SQL execution failed: \(msg)"
        }
    }
}

// MARK: - Environment Helpers

func echoTestEnv(_ key: String) -> String? {
    if let value = getenv(key) {
        return String(cString: value)
    }
    if let value = echoFixtureEnvValue(key) {
        return value
    }
    return ProcessInfo.processInfo.environment[key]
}

func echoTestEnvFlag(_ key: String) -> Bool {
    guard let value = echoTestEnv(key)?.lowercased() else { return false }
    return value == "1" || value == "true" || value == "yes"
}

private func echoFixtureEnvValue(_ key: String) -> String? {
    let sourceRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    var candidates: [URL] = [
        sourceRoot.appendingPathComponent(".ci-fixtures/test-fixtures.env")
    ]
    var currentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    for _ in 0..<8 {
        candidates.append(currentURL.appendingPathComponent(".ci-fixtures/test-fixtures.env"))
        currentURL.deleteLastPathComponent()
    }

    for fileURL in candidates {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == key else { continue }
            return parts[1]
        }
    }

    return nil
}
