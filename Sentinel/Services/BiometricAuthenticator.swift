import Foundation
import LocalAuthentication

enum BiometricAvailability: Equatable {
    case available
    case notEnrolled
    case unavailable(String)

    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    var statusText: String {
        switch self {
        case .available:
            return "Touch ID 可用"
        case .notEnrolled:
            return "尚未录入指纹"
        case .unavailable(let reason):
            return reason
        }
    }
}

final class BiometricAuthenticator {
    private let stateLock = NSLock()
    private var activeContext: LAContext?

    var availability: BiometricAvailability {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error as? LAError {
                switch error.code {
                case .biometryNotEnrolled:
                    return .notEnrolled
                case .biometryNotAvailable:
                    return .unavailable("此 Mac 不支持生物识别")
                case .biometryLockout:
                    return .unavailable("Touch ID 暂时锁定，请使用密码")
                default:
                    return .unavailable(error.localizedDescription)
                }
            }
            return .unavailable(error?.localizedDescription ?? "Touch ID 不可用")
        }
        return .available
    }

    func authenticate(reason: String) async -> Bool {
        guard availability.isAvailable else {
            return false
        }

        let context = LAContext()
        context.localizedCancelTitle = "使用密码"
        context.localizedFallbackTitle = ""
        context.touchIDAuthenticationAllowableReuseDuration = 0

        stateLock.lock()
        activeContext?.invalidate()
        activeContext = context
        stateLock.unlock()

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { [weak self] success, _ in
                self?.clear(context: context)
                continuation.resume(returning: success)
            }
        }
    }

    func cancel() {
        stateLock.lock()
        let context = activeContext
        activeContext = nil
        stateLock.unlock()
        context?.invalidate()
    }

    private func clear(context: LAContext) {
        stateLock.lock()
        if activeContext === context {
            activeContext = nil
        }
        stateLock.unlock()
    }
}
