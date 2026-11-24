import SwiftUI

struct LockScreenView: View {
    @ObservedObject var model: LockViewModel
    let isPrimaryDisplay: Bool

    var body: some View {
        ZStack {
            LiveGlassBackground(intensity: model.glassIntensity)

            if isPrimaryDisplay && model.showsPasswordEntry {
                passwordInterface
                    .transition(.opacity.combined(with: .scale(scale: 0.975)))
            } else {
                idleHint
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.42), value: model.showsPasswordEntry)
    }

    private var idleHint: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 76, height: 76)
                Circle()
                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
                    .frame(width: 76, height: 76)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 29, weight: .light))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .shadow(color: .black.opacity(0.26), radius: 24, y: 12)

            VStack(spacing: 7) {
                Text("SENTINEL")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(5)
                    .foregroundStyle(.white.opacity(0.50))
                Text("保护中")
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                Text(
                    model.showsPasswordEntry && !isPrimaryDisplay
                        ? "请在主显示器上输入解锁密码"
                        : "移动鼠标或点按鼠标以解锁"
                )
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.54))
            }
        }
    }

    private var passwordInterface: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text("SENTINEL")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(5)
                    .foregroundStyle(.white.opacity(0.42))

                Text("输入密码")
                    .font(.system(size: 33, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))

                pinIndicators
                    .padding(.top, 5)

                HStack(spacing: 7) {
                    if model.isVerifying || model.isBiometricPrompting {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white.opacity(0.7))
                    }
                    Text(model.message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(
                            model.showsError
                                ? Color(red: 1.0, green: 0.45, blue: 0.48)
                                : Color.white.opacity(0.52)
                        )
                        .contentTransition(.numericText())
                }
                .frame(height: 18)
            }
            .modifier(ShakeEffect(shakes: CGFloat(model.errorPulse)))
            .animation(.easeInOut(duration: 0.42), value: model.errorPulse)

            keypad

            VStack(spacing: 8) {
                if model.touchIDConfigured {
                    Label(
                        model.touchIDAvailable ? "Touch ID 可用" : "Touch ID 当前不可用",
                        systemImage: "touchid"
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(model.touchIDAvailable ? 0.48 : 0.30))
                }

                Text("仅接受键盘数字 0–9")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.30))
            }
        }
        .padding(.horizontal, 38)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(Color.white.opacity(0.022))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.035),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: .black.opacity(0.26), radius: 44, y: 22)
    }

    private var pinIndicators: some View {
        HStack(spacing: 15) {
            ForEach(0..<LockViewModel.passwordLength, id: \.self) { index in
                ZStack {
                    Circle()
                        .strokeBorder(
                            index < model.enteredDigits.count
                                ? Color.white.opacity(0.95)
                                : Color.white.opacity(0.48),
                            lineWidth: 1.2
                        )
                        .frame(width: 14, height: 14)

                    if index < model.enteredDigits.count {
                        Circle()
                            .fill(Color.white.opacity(0.96))
                            .frame(width: 6.5, height: 6.5)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.24, dampingFraction: 0.74), value: model.enteredDigits)
            }
        }
        .accessibilityLabel("六位密码")
        .accessibilityValue("已输入 \(model.enteredDigits.count) 位")
    }

    private var keypad: some View {
        VStack(spacing: 12) {
            HStack(spacing: 17) {
                keypadKey("1", letters: nil)
                keypadKey("2", letters: "ABC")
                keypadKey("3", letters: "DEF")
            }
            HStack(spacing: 17) {
                keypadKey("4", letters: "GHI")
                keypadKey("5", letters: "JKL")
                keypadKey("6", letters: "MNO")
            }
            HStack(spacing: 17) {
                keypadKey("7", letters: "PQRS")
                keypadKey("8", letters: "TUV")
                keypadKey("9", letters: "WXYZ")
            }
            HStack(spacing: 17) {
                Color.clear
                    .frame(width: 68, height: 68)
                keypadKey("0", letters: nil)
                Color.clear
                    .frame(width: 68, height: 68)
            }
        }
    }

    private func keypadKey(_ number: String, letters: String?) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.012)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.26),
                            Color.white.opacity(0.055)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )

            VStack(spacing: 0) {
                Text(number)
                    .font(.system(size: letters == nil ? 27 : 24, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))

                if let letters {
                    Text(letters)
                        .font(.system(size: 7.5, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.54))
                        .offset(y: -1)
                }
            }
        }
        .frame(width: 68, height: 68)
        .shadow(color: .black.opacity(0.16), radius: 10, y: 6)
    }
}

private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 9
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(shakes * .pi * 2),
                y: 0
            )
        )
    }
}
