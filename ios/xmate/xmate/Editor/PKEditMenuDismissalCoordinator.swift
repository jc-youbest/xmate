// PKEditMenuDismissalCoordinator
//
// Narrow guard for PencilKit's private selection/edit menu recognizers.
// At 100%, xmate allows PencilKit's finger single-tap menu. Once that menu is
// assumed visible, the next finger single-tap inside the canvas is treated as
// dismissal-only: the app recognizer wins, PencilKit's selection taps fail, and
// a short suppression window prevents the same tap from immediately reopening
// the menu. Apple Pencil drawing recognizers are never touched.

import UIKit

final class PKEditMenuDismissalCoordinator {
    private enum Constants {
        static let reopenSuppression: TimeInterval = 0.35
    }

    private var menuAssumedVisible = false
    private var suppressReopenUntil: TimeInterval = 0
    private var suppressWork: DispatchWorkItem?

    /// Called by the app's finger-only single-tap dismiss recognizer delegate.
    /// Return true only when the tap should dismiss an already-visible menu.
    /// Return false for the normal first tap so PencilKit can show its menu.
    func shouldBeginDismissTap(menuAllowed: Bool) -> Bool {
        guard menuAllowed else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        if menuAssumedVisible || now < suppressReopenUntil {
            return true
        }

        menuAssumedVisible = true
        #if DEBUG
        print("[PK-MENU] visible=true")
        #endif
        return false
    }

    func handleDismissTap(from view: UIView?, onSuppressionEnded: @escaping () -> Void) {
        #if DEBUG
        print("[PK-MENU] dismiss requested by canvas tap")
        #endif
        hideLegacyMenu(from: view)
        startReopenSuppression(onEnded: onSuppressionEnded)
    }

    var suppressesSelectionTapForDismissal: Bool {
        ProcessInfo.processInfo.systemUptime < suppressReopenUntil
    }

    func selectionTapWasSuppressedForDismissal() {
        #if DEBUG
        print("[PK-MENU] selection tap suppressed for dismissal")
        #endif
    }

    private func startReopenSuppression(onEnded: @escaping () -> Void) {
        menuAssumedVisible = false
        suppressWork?.cancel()
        suppressReopenUntil =
            ProcessInfo.processInfo.systemUptime + Constants.reopenSuppression
        #if DEBUG
        print("[PK-MENU] suppress reopen window started")
        #endif

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.suppressReopenUntil = 0
            #if DEBUG
            print("[PK-MENU] suppress reopen window ended")
            #endif
            onEnded()
        }
        suppressWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.reopenSuppression,
            execute: work
        )
    }

    private func hideLegacyMenu(from view: UIView?) {
        guard let menuControllerClass = NSClassFromString("UIMenuController") as? NSObject.Type else {
            return
        }
        let sharedSelector = NSSelectorFromString("sharedMenuController")
        guard menuControllerClass.responds(to: sharedSelector),
              let controller = menuControllerClass.perform(sharedSelector)?
                  .takeUnretainedValue() as? NSObject else {
            return
        }

        if let view {
            let selector = NSSelectorFromString("hideMenuFromView:")
            if controller.responds(to: selector) {
                _ = controller.perform(selector, with: view)
            }
        } else {
            let selector = NSSelectorFromString("hideMenu")
            if controller.responds(to: selector) {
                _ = controller.perform(selector)
            }
        }
    }
}
