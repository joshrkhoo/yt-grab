// Renders a scripted YT Grab session to PNG frames using the real PanelView.
// Built by demo/make-demo.sh, which turns the frames into docs/demo.gif.
import SwiftUI
import AppKit

let W: CGFloat = 600
let H: CGFloat = 390
let fps = 15.0
let scale: CGFloat = 2

@MainActor
final class DemoState: ObservableObject {
    @Published var cursor = CGPoint(x: 230, y: 300)
    @Published var panelOpen = false
    @Published var iconActive = false
    @Published var percent = 0
    @Published var keycap: String?
    @Published var clickAt: CGPoint?
    @Published var clickAge = 0.0
}

struct Arrow: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: 0, y: 17))
        p.addLine(to: CGPoint(x: 4.2, y: 13))
        p.addLine(to: CGPoint(x: 7, y: 19.5))
        p.addLine(to: CGPoint(x: 9.6, y: 18.4))
        p.addLine(to: CGPoint(x: 6.9, y: 12.1))
        p.addLine(to: CGPoint(x: 12.4, y: 12.1))
        p.closeSubpath()
        return p
    }
}

struct DemoScene: View {
    @ObservedObject var s: DemoState
    @ObservedObject var dl: Downloader

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(red: 0.30, green: 0.42, blue: 0.86), Color(red: 0.72, green: 0.42, blue: 0.78)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                menuBar
                HStack {
                    Spacer()
                    if s.panelOpen {
                        PanelView()
                            .environmentObject(dl)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.black.opacity(0.18)))
                            .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
                            .padding(.trailing, 92)
                    }
                }
                .padding(.top, 6)
                Spacer()
            }

            if let k = s.keycap {
                Text(k)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.65)))
                    .position(x: 150, y: H - 50)
            }

            if let c = s.clickAt {
                Circle()
                    .stroke(Color.white.opacity(0.9 * (1 - s.clickAge)), lineWidth: 2.5)
                    .frame(width: 10 + 30 * s.clickAge, height: 10 + 30 * s.clickAge)
                    .position(c)
            }

            ZStack(alignment: .topLeading) {
                Arrow().fill(Color.black)
                Arrow().stroke(Color.white, lineWidth: 1.3)
            }
            .frame(width: 13, height: 20)
            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
            .offset(x: s.cursor.x, y: s.cursor.y)
        }
        .frame(width: W, height: H)
        .environment(\.colorScheme, .light)
    }

    var menuBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "apple.logo").font(.system(size: 14))
            Text("Finder").fontWeight(.semibold)
            Text("File")
            Text("Edit")
            Text("View")
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: s.iconActive ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 15))
                if s.iconActive {
                    Text("\(s.percent)%").monospacedDigit()
                }
            }
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(s.panelOpen ? 0.28 : 0)))
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("Fri 4:41 PM")
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 26)
        .background(Color.black.opacity(0.22))
    }
}

// Key positions in scene coordinates (top-left origin), measured from rendered frames
let iconPos = CGPoint(x: 425, y: 13)
let downloadBtn = CGPoint(x: 451, y: 160)
let finderBtn = CGPoint(x: 490, y: 219)
let restPos = CGPoint(x: 230, y: 300)

let links = """
https://youtu.be/jNQXAC9IVRw
https://youtu.be/aqz-KE-bpKQ
https://youtu.be/eRsGyueVLvQ
"""
let titles = ["Me at the zoo", "Big Buck Bunny 60fps 4K - Official Blender Foundation Short Film", "Sintel - Open Movie by Blender Foundation"]
let urls = links.split(separator: "\n").map(String.init)

func ease(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }
func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    let e = ease(min(max(t, 0), 1))
    return CGPoint(x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e)
}
func phase(_ t: Double, _ start: Double, _ end: Double) -> Double { (t - start) / (end - start) }

// Per-job: when its title resolves, and download start/end times
let jobTiming: [(title: Double, start: Double, end: Double)] = [(4.3, 4.4, 5.6), (4.6, 4.8, 8.0), (4.8, 5.0, 7.0)]
let total = 11.5

@MainActor
func apply(_ t: Double, _ s: DemoState, _ dl: Downloader) {
    // Cursor path
    if t < 0.6 { s.cursor = restPos }
    else if t < 1.4 { s.cursor = lerp(restPos, iconPos, phase(t, 0.6, 1.4)) }
    else if t < 3.0 { s.cursor = iconPos }
    else if t < 3.8 { s.cursor = lerp(iconPos, downloadBtn, phase(t, 3.0, 3.8)) }
    else if t < 8.6 { s.cursor = downloadBtn }
    else if t < 9.4 { s.cursor = lerp(downloadBtn, finderBtn, phase(t, 8.6, 9.4)) }
    else { s.cursor = finderBtn }

    // Clicks
    let clicks = [(1.45, iconPos), (3.9, downloadBtn)]
    s.clickAt = nil
    for (ct, pos) in clicks where t >= ct && t < ct + 0.4 {
        s.clickAt = pos
        s.clickAge = (t - ct) / 0.4
    }

    s.panelOpen = t >= 1.45
    s.keycap = (t >= 2.0 && t < 2.8) ? "⌘V" : nil
    dl.draft = (t >= 2.25 && t < 3.9) ? links : ""

    // Jobs
    if t >= 3.9 && dl.jobs.isEmpty {
        dl.jobs = urls.reversed().map { Job(url: $0) }
    }
    if t < 3.9 { dl.jobs = [] }
    let ordered = Array(dl.jobs.reversed())
    for (i, job) in ordered.enumerated() {
        let tm = jobTiming[i]
        job.title = t >= tm.title ? titles[i] : urls[i]
        if t >= tm.end {
            job.state = .done
            job.progress = 1
            job.filePath = "/tmp/x"
        } else {
            job.state = .running
            let p = max(0, phase(t, tm.start, tm.end))
            job.progress = p
            job.started = t >= tm.start
            let left = Int(ceil((tm.end - t) * 1.6))
            job.detail = job.started
                ? "Downloading video · \(Int(p * 100))% · \(String(format: "%.1f", 3.2 + Double(i) * 1.1)) MB/s · 00:\(String(format: "%02d", left)) left"
                : "Starting…"
        }
    }
    s.iconActive = dl.jobs.contains { $0.state == .running }
    s.percent = Int(dl.overallProgress * 100)
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "frames"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// AppKit greys out controls in inactive apps/windows; macOS won't let a CLI-launched
// process become active, so the recorder reports itself as active instead
final class DemoApp: NSApplication {
    override var isActive: Bool { true }
}
let app = DemoApp.shared
// Active app + key window so controls draw in their accent colour, as in the real panel
app.setActivationPolicy(.accessory)

final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
}

MainActor.assumeIsolated {
    let state = DemoState()
    let dl = Downloader()
    dl.format = .mp4
    dl.quality = 1080
    dl.bitrate = 320

    let host = NSHostingView(rootView: DemoScene(s: state, dl: dl))
    host.frame = NSRect(x: 0, y: 0, width: W, height: H)
    let win = KeyWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    win.contentView = host
    win.appearance = NSAppearance(named: .aqua)
    win.setFrameOrigin(NSPoint(x: -20000, y: -20000))
    win.orderFrontRegardless()
    app.activate(ignoringOtherApps: true)
    win.makeKey()

    var frame = 0
    let frameCount = Int(total * fps)
    apply(0, state, dl)

    Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { timer in
        MainActor.assumeIsolated {
            host.layoutSubtreeIfNeeded()
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            )!
            rep.size = host.bounds.size
            host.cacheDisplay(in: host.bounds, to: rep)
            let path = String(format: "%@/f%04d.png", outDir, frame)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))

            frame += 1
            if frame >= frameCount {
                timer.invalidate()
                exit(0)
            }
            apply(Double(frame) / fps, state, dl)
        }
    }
}

app.run()
