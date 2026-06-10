import SwiftUI
import UIKit

/// Restores the edge swipe-to-go-back gesture on screens that hide the
/// navigation bar.
///
/// When a view sets `.toolbar(.hidden, for: .navigationBar)`, UIKit disables the
/// host `UINavigationController`'s `interactivePopGestureRecognizer`, so the
/// system swipe-from-left-edge pop stops working and only a custom back button
/// remains. This representable reaches the enclosing navigation controller, takes
/// over the recognizer's delegate, and re-enables the gesture — scoped to the
/// screen that asks for it, so we don't globally override every nav controller.
///
/// Pass a `canPop`/`onBlocked` pair to guard the pop (e.g. confirm discarding
/// unsaved form edits): when `canPop` returns false the edge swipe is swallowed
/// and `onBlocked` runs instead of popping.
private struct InteractiveSwipeBack: UIViewControllerRepresentable {
    var canPop: () -> Bool
    var onBlocked: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        Controller(canPop: canPop, onBlocked: onBlocked)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let controller = uiViewController as? Controller else { return }
        controller.canPop = canPop
        controller.onBlocked = onBlocked
    }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        var canPop: () -> Bool
        var onBlocked: () -> Void

        init(canPop: @escaping () -> Bool, onBlocked: @escaping () -> Void) {
            self.canPop = canPop
            self.onBlocked = onBlocked
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            guard let recognizer = navigationController?.interactivePopGestureRecognizer else { return }
            recognizer.delegate = self
            recognizer.isEnabled = true
        }

        // Only allow the pop gesture when there's something to pop back to and the
        // screen permits it; otherwise swallow the swipe and notify (e.g. confirm).
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard (navigationController?.viewControllers.count ?? 0) > 1 else { return false }
            if canPop() { return true }
            onBlocked()
            return false
        }
    }
}

extension View {
    /// Re-enables the interactive swipe-back pop gesture on a nav-bar-hidden screen.
    func enableInteractiveSwipeBack() -> some View {
        background(InteractiveSwipeBack(canPop: { true }, onBlocked: {}).frame(width: 0, height: 0))
    }

    /// Like `enableInteractiveSwipeBack()`, but guards the pop: when `canPop`
    /// returns false the edge swipe is intercepted and `onBlocked` runs instead
    /// of popping — e.g. to confirm discarding unsaved form edits.
    func interactiveSwipeBack(
        canPop: @escaping () -> Bool,
        onBlocked: @escaping () -> Void
    ) -> some View {
        background(InteractiveSwipeBack(canPop: canPop, onBlocked: onBlocked).frame(width: 0, height: 0))
    }
}
