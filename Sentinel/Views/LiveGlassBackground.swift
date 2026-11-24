import AppKit
import SwiftUI

struct LiveGlassBackground: View {
    let intensity: Double

    var body: some View {
        ZStack {
            if #available(macOS 26.0, *) {
                NativeLiquidGlassBackdrop()
            } else {
                VisualEffectBackdrop(
                    material: .fullScreenUI,
                    blendingMode: .behindWindow
                )
            }

            VisualEffectBackdrop(
                material: .hudWindow,
                blendingMode: .behindWindow
            )
            .opacity(0.10 + intensity * 0.74)

            LiquidLightField(intensity: intensity)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.02),
                    Color.black.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.28 + intensity * 0.72)

            Color.black.opacity(0.02 + intensity * 0.24)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.52), value: intensity)
    }
}

@available(macOS 26.0, *)
private struct NativeLiquidGlassBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NativeGlassView {
        let view = NativeGlassView()
        view.style = .clear
        view.cornerRadius = 0
        view.tintColor = NSColor(
            calibratedRed: 0.16,
            green: 0.25,
            blue: 0.40,
            alpha: 0.11
        )
        let contentView = NSView(frame: .zero)
        view.contentView = contentView
        return view
    }

    func updateNSView(_ nsView: NativeGlassView, context: Context) {
        nsView.contentView?.frame = nsView.bounds
    }
}

@available(macOS 26.0, *)
private final class NativeGlassView: NSGlassEffectView {
    override func layout() {
        super.layout()
        contentView?.frame = bounds
    }
}

private struct VisualEffectBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        if nsView.material != material {
            nsView.material = material
        }
        if nsView.blendingMode != blendingMode {
            nsView.blendingMode = blendingMode
        }
        if nsView.state != .active {
            nsView.state = .active
        }
    }
}

private struct LiquidLightField: View {
    let intensity: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            GeometryReader { proxy in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let width = proxy.size.width
                let height = proxy.size.height

                ZStack {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.19, green: 0.72, blue: 1.0).opacity(0.30),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: min(width, height) * 0.36
                            )
                        )
                        .frame(width: width * 0.72, height: height * 0.58)
                        .blur(radius: 34)
                        .offset(
                            x: CGFloat(sin(time * 0.14)) * width * 0.16 - width * 0.16,
                            y: CGFloat(cos(time * 0.11)) * height * 0.10 - height * 0.12
                        )

                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.51, green: 0.40, blue: 1.0).opacity(0.24),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: min(width, height) * 0.31
                            )
                        )
                        .frame(width: width * 0.64, height: height * 0.54)
                        .blur(radius: 44)
                        .offset(
                            x: CGFloat(cos(time * 0.10)) * width * 0.13 + width * 0.18,
                            y: CGFloat(sin(time * 0.13)) * height * 0.12 + height * 0.12
                        )

                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.11),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: min(width, height) * 0.24
                            )
                        )
                        .frame(width: width * 0.48, height: height * 0.42)
                        .blur(radius: 30)
                        .offset(
                            x: CGFloat(sin(time * 0.09 + 1.7)) * width * 0.10,
                            y: CGFloat(cos(time * 0.08 + 0.9)) * height * 0.08
                        )
                }
                .frame(width: width, height: height)
                .blendMode(.screen)
            }
        }
        .opacity(0.28 + intensity * 0.30)
        .allowsHitTesting(false)
    }
}
