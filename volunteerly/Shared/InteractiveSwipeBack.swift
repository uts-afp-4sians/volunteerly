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
private struct InteractiveSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Controller() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            guard let recognizer = navigationController?.interactivePopGestureRecognizer else { return }
            recognizer.delegate = self
            recognizer.isEnabled = true
        }

        // Only allow the pop gesture when there's something to pop back to.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

extension View {
    /// Re-enables the interactive swipe-back pop gesture on a nav-bar-hidden screen.
    func enableInteractiveSwipeBack() -> some View {
        background(InteractiveSwipeBack().frame(width: 0, height: 0))
    }
}
