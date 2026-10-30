import AppKit
import Sparkle
import SterlingUpdateSupport

@MainActor final class AppUpdater: NSObject {
  private let controller: SPUStandardUpdaterController

  init?(isProbe: Bool) {
    guard UpdateConfiguration(info: Bundle.main.infoDictionary ?? [:], isProbe: isProbe) != nil
    else { return nil }
    controller = SPUStandardUpdaterController(
      startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    super.init()
    // Automatic checks are opt-in. Local builds and probes never start Sparkle.
    do { try controller.updater.start() } catch { return nil }
  }

  func addMenuItems(to menu: NSMenu) {
    let check = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
    check.target = controller
    menu.addItem(check)
    let automatic = NSMenuItem(title: "Check for Updates Automatically", action: #selector(toggleAutomaticChecks(_:)), keyEquivalent: "")
    automatic.target = self
    automatic.state = controller.updater.automaticallyChecksForUpdates ? .on : .off
    menu.addItem(automatic)
  }

  @objc private func toggleAutomaticChecks(_ sender: NSMenuItem) {
    controller.updater.automaticallyChecksForUpdates.toggle()
    sender.state = controller.updater.automaticallyChecksForUpdates ? .on : .off
  }
}
