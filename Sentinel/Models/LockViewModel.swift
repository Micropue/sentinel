import Combine
import Foundation

@MainActor
final class LockViewModel: ObservableObject {
    static let passwordLength = 6

    let biometricUnlockAvailable: Bool

    @Published private(set) var glassIntensity = 0.0
    @Published private(set) var showsPasswordEntry = false
    @Published private(set) var enteredDigits = ""
    @Published private(set) var isVerifying = false
    @Published private(set) var isBiometricPrompting = false
    @Published private(set) var showsError = false

    init(biometricUnlockAvailable: Bool = false) {
        self.biometricUnlockAvailable = biometricUnlockAvailable
    }

    func registerUserActivity() {
        if glassIntensity != 1 {
            glassIntensity = 1
        }
        if !showsPasswordEntry {
            showsPasswordEntry = true
        }
    }

    @discardableResult
    func appendDigit(_ digit: Character) -> Bool {
        guard showsPasswordEntry,
              !isVerifying,
              enteredDigits.count < Self.passwordLength
        else {
            return false
        }

        showsError = false
        enteredDigits.append(digit)
        return enteredDigits.count == Self.passwordLength
    }

    func beginVerification() {
        isVerifying = true
        showsError = false
    }

    func rejectPassword() {
        isVerifying = false
        isBiometricPrompting = false
        enteredDigits = ""
        showsError = true
    }

    func beginBiometricPrompt() {
        isBiometricPrompting = true
        showsError = false
    }

    func finishBiometricPrompt(success: Bool) {
        isBiometricPrompting = false
        if !success {
            showsError = true
        }
    }

    func cancelBiometricPrompt() {
        isBiometricPrompting = false
    }

    func returnToIdle() {
        enteredDigits = ""
        isVerifying = false
        isBiometricPrompting = false
        showsError = false
        showsPasswordEntry = false
        glassIntensity = 0
    }
}
