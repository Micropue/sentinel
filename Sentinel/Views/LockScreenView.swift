import SwiftUI

struct LockScreenView: View {
    @ObservedObject var model: LockViewModel
    let isPrimaryDisplay: Bool

    var body: some View {
        LiveGlassBackground(intensity: model.glassIntensity)
            .overlay {
                if isPrimaryDisplay && model.showsPasswordEntry {
                    passwordEntry
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .topLeading) {
                lockBadge
                    .padding(.leading, 22)
                    .padding(.top, 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .preferredColorScheme(.dark)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.24), value: model.showsPasswordEntry)
    }

    private var passwordEntry: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("你需要先解锁Mac")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.65), radius: 4, y: 1)

                pinIndicators
            }

            if model.biometricUnlockAvailable {
                biometricIndicator
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
    }

    private var lockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: 42, height: 42)
            .background(Color.black, in: Circle())
            .shadow(color: Color.black.opacity(0.25), radius: 8, y: 3)
            .accessibilityLabel("Sentinel 已锁定")
    }

    private var pinIndicators: some View {
        HStack(spacing: 18) {
            ForEach(0..<LockViewModel.passwordLength, id: \.self) { index in
                if index < model.enteredDigits.count {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 18, height: 18)
                } else {
                    Circle()
                        .strokeBorder(
                            indicatorColor.opacity(0.76),
                            lineWidth: 1.8
                        )
                        .frame(width: 18, height: 18)
                }
            }
        }
        .animation(.easeInOut(duration: 0.14), value: model.enteredDigits)
        .animation(.easeInOut(duration: 0.18), value: model.showsError)
        .shadow(color: Color.black.opacity(0.65), radius: 4, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("六位解锁密码")
        .accessibilityValue("已输入 \(model.enteredDigits.count) 位")
    }

    private var biometricIndicator: some View {
        Image(systemName: "touchid")
            .font(.system(size: 34, weight: .light))
            .foregroundStyle(
                Color.white.opacity(model.isBiometricPrompting ? 0.96 : 0.7)
            )
            .symbolEffect(
                .pulse,
                options: .repeating,
                isActive: model.isBiometricPrompting
            )
            .shadow(color: Color.black.opacity(0.65), radius: 5, y: 1)
            .accessibilityLabel("Touch ID")
    }

    private var indicatorColor: Color {
        model.showsError ? Color(red: 1, green: 0.34, blue: 0.38) : .white
    }
}
