import SwiftUI
import AppKit

enum Format: String, CaseIterable, Identifiable {
    case mp4 = "MP4"
    case mp3 = "MP3"
    var id: String { rawValue }
}

enum JobState: Equatable {
    case running
    case done
    case failed(String)
}

// Reassembles pipe chunks into whole lines; only touched from one pipe's handler queue
final class LineBuffer: @unchecked Sendable {
    private var pending = Data()

    func append(_ data: Data) -> [String] {
        pending.append(data)
        var lines: [String] = []
        while let nl = pending.firstIndex(of: 0x0A) {
            let lineData = pending[pending.startIndex..<nl]
            pending.removeSubrange(pending.startIndex...nl)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }
}

@MainActor
final class Job: ObservableObject, Identifiable {
    let id = UUID()
    let url: String
    let isAudio: Bool
    @Published var title: String
    @Published var progress: Double = 0
    @Published var state: JobState = .running
    @Published var filePath: String?
    // False until the first byte arrives; the bar animates instead of sitting empty
    @Published var started = false
    // True while ffmpeg merges or converts after the download
    @Published var processing = false
    @Published var detail = "Starting…"
    var lastError = ""
    var process: Process?

    init(url: String, isAudio: Bool = false) {
        self.url = url
        self.isAudio = isAudio
        self.title = url
    }
}

@MainActor
final class Downloader: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var draft = ""
    @AppStorage("format") var format: Format = .mp4
    @AppStorage("quality") var quality: Int = 1080
    @AppStorage("bitrate") var bitrate: Int = 320

    let outDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")

    var scriptPath: String {
        Bundle.main.path(forResource: "ytgrab", ofType: nil) ?? "/usr/local/bin/ytgrab"
    }

    var activeCount: Int { jobs.filter { $0.state == .running }.count }

    var overallProgress: Double {
        let running = jobs.filter { $0.state == .running }
        guard !running.isEmpty else { return 0 }
        return running.map(\.progress).reduce(0, +) / Double(running.count)
    }

    func start(_ text: String) {
        let links = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.hasPrefix("http") }
        for link in links {
            let job = Job(url: link, isAudio: format == .mp3)
            jobs.insert(job, at: 0)
            run(job)
        }
    }

    private func run(_ job: Job) {
        var args = [scriptPath]
        if format == .mp3 {
            args += ["--audio", "--bitrate", String(bitrate)]
        } else {
            args += ["--quality", String(quality)]
        }
        args += ["--out", outDir.path, job.url]

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["YTGRAB_MACHINE"] = "1"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        p.environment = env

        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err

        let outLines = LineBuffer()
        out.fileHandleForReading.readabilityHandler = { h in
            let lines = outLines.append(h.availableData)
            guard !lines.isEmpty else { return }
            Task { @MainActor in
                for line in lines { self.handle(line, job: job) }
            }
        }
        err.fileHandleForReading.readabilityHandler = { h in
            guard let s = String(data: h.availableData, encoding: .utf8), !s.isEmpty else { return }
            if let line = s.split(separator: "\n").last(where: { $0.contains("ERROR") }) {
                let msg = line.replacingOccurrences(of: "ERROR: ", with: "")
                Task { @MainActor in job.lastError = msg }
            }
        }
        p.terminationHandler = { proc in
            out.fileHandleForReading.readabilityHandler = nil
            err.fileHandleForReading.readabilityHandler = nil
            let code = proc.terminationStatus
            Task { @MainActor in
                let msg = job.lastError
                if code == 0 {
                    job.state = .done
                    job.progress = 1
                    NSSound(named: "Glass")?.play()
                } else if job.state == .running {
                    job.state = .failed(msg.isEmpty ? "Download failed" : msg)
                }
            }
        }

        job.process = p
        do {
            try p.run()
        } catch {
            job.state = .failed(error.localizedDescription)
        }
    }

    private func handle(_ line: String, job: Job) {
        // Job changes don't publish through Downloader, so nudge it for the menu-bar percentage
        objectWillChange.send()
        if line.hasPrefix("TITLE ") {
            job.title = String(line.dropFirst(6))
        } else if line.hasPrefix("FILE ") {
            job.filePath = String(line.dropFirst(5))
        } else if line.hasPrefix("PCT ") {
            handleProgress(String(line.dropFirst(4)), job: job)
        } else if line.hasPrefix("POST ") {
            let parts = line.dropFirst(5).split(separator: "|").map(String.init)
            guard parts.count == 2, parts[1] == "started" else { return }
            switch parts[0] {
            case "Merger": job.detail = "Merging video and audio…"
            case "ExtractAudio": job.detail = "Converting to MP3…"
            case "FFmpegVideoRemuxer", "FFmpegVideoConvertor": job.detail = "Converting to MP4…"
            default: return
            }
            job.processing = true
        }
    }

    // Line format: percent|speed|eta|vcodec|acodec
    private func handleProgress(_ payload: String, job: Job) {
        let f = payload.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard f.count >= 5, let pct = Double(f[0].replacingOccurrences(of: "%", with: "")) else { return }
        let part = pct / 100
        let hasVideo = f[3] != "none" && !f[3].isEmpty && f[3] != "NA"
        let hasAudio = f[4] != "none" && !f[4].isEmpty && f[4] != "NA"

        // A video download is usually two passes (picture, then sound); give the sound the last 10%
        let label: String
        if job.isAudio || (hasVideo && hasAudio) {
            job.progress = part
            label = "Downloading"
        } else if hasVideo {
            job.progress = part * 0.9
            label = "Downloading video"
        } else {
            job.progress = 0.9 + part * 0.1
            label = "Downloading audio"
        }
        job.started = true
        job.processing = false

        var bits = [label, "\(Int(pct))%"]
        if !f[1].isEmpty, !f[1].contains("Unknown"), f[1] != "NA" {
            bits.append(f[1].replacingOccurrences(of: "iB", with: "B"))
        }
        if !f[2].isEmpty, !f[2].contains("Unknown"), f[2] != "NA" {
            bits.append("\(f[2]) left")
        }
        job.detail = bits.joined(separator: " · ")
    }

    func cancel(_ job: Job) {
        job.process?.terminate()
        job.state = .failed("Cancelled")
    }

    func clearFinished() {
        jobs.removeAll { $0.state != .running }
    }
}

struct JobRow: View {
    @ObservedObject var job: Job
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                Text(job.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.system(size: 12, weight: .medium))
                switch job.state {
                case .running:
                    Group {
                        if job.started && !job.processing {
                            ProgressView(value: job.progress)
                        } else {
                            ProgressView()
                        }
                    }
                    .progressViewStyle(.linear)
                    .controlSize(.small)
                    .tint(.accentColor)
                    Text(job.detail)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                case .done:
                    Text("Saved").font(.caption).foregroundStyle(.secondary)
                case .failed(let msg):
                    Text(msg).font(.caption).foregroundStyle(.red).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if job.state == .running {
                Button(action: onCancel) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Cancel")
            } else if let path = job.filePath, job.state == .done {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                } label: { Image(systemName: "magnifyingglass.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Show in Finder")
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder var icon: some View {
        switch job.state {
        case .running: ProgressView().controlSize(.small).frame(width: 16)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).frame(width: 16)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).frame(width: 16)
        }
    }
}

private struct ListHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct PanelView: View {
    @EnvironmentObject var dl: Downloader
    @State private var listHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YT Grab").font(.headline)
                Spacer()
                Picker("", selection: $dl.format) {
                    ForEach(Format.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
                .labelsHidden()
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $dl.draft)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .frame(height: 70)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                if dl.draft.isEmpty {
                    Text("Paste links, one per line")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                if dl.format == .mp4 {
                    Picker("Quality", selection: $dl.quality) {
                        ForEach([2160, 1440, 1080, 720, 480, 360], id: \.self) { Text("\($0)p").tag($0) }
                    }
                    .frame(width: 150)
                } else {
                    Picker("Bitrate", selection: $dl.bitrate) {
                        ForEach([320, 256, 192, 128], id: \.self) { Text("\($0) kb/s").tag($0) }
                    }
                    .frame(width: 160)
                }
                Spacer()
                Button("Paste") {
                    if let s = NSPasteboard.general.string(forType: .string) {
                        dl.draft = dl.draft.isEmpty ? s : dl.draft + "\n" + s
                    }
                }
                Button("Download") {
                    dl.start(dl.draft)
                    dl.draft = ""
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!dl.draft.contains("http"))
            }
            .controlSize(.small)

            if !dl.jobs.isEmpty {
                Divider()
                // Size the list to its rows, scrolling only past 220pt
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(dl.jobs) { job in
                            JobRow(job: job) { dl.cancel(job) }
                        }
                    }
                    .background(GeometryReader { g in
                        Color.clear.preference(key: ListHeightKey.self, value: g.size.height)
                    })
                }
                .frame(height: min(listHeight, 220))
                .onPreferenceChange(ListHeightKey.self) { listHeight = $0 }
            }

            Divider()
            HStack {
                Button("Open Downloads") { NSWorkspace.shared.open(dl.outDir) }
                if dl.jobs.contains(where: { $0.state != .running }) {
                    Button("Clear finished") { dl.clearFinished() }
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(12)
        .frame(width: 340)
    }
}

// The demo recorder (demo/main.swift) supplies its own entry point
#if !DEMO
@main
struct YTGrabApp: App {
    @StateObject private var dl = Downloader()

    var body: some Scene {
        MenuBarExtra {
            PanelView().environmentObject(dl)
        } label: {
            if dl.activeCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("\(Int(dl.overallProgress * 100))%").monospacedDigit()
                }
            } else {
                Image(systemName: "arrow.down.circle")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
#endif
