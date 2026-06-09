import ServiceManagement
import Foundation
import os

final class LoginItemService {

    static let shared = LoginItemService()

    private let logger = Logger(subsystem: "com.mateusz.dango", category: "loginItem")

    private init() {}

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Login item registration failed: \(error.localizedDescription)")
        }
    }

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
