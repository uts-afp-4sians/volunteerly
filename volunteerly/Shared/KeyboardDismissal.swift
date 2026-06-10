import SwiftUI
import UIKit

extension View {
    func keyboardDismissable() -> some View {
        background(KeyboardDismissalInstaller())
    }
}

private struct KeyboardDismissalInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.install(in: view.window)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.install(in: uiView.window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private lazy var recognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(dismissKeyboard)
            )
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        func install(in window: UIWindow?) {
            guard let window, installedWindow !== window else { return }
            installedWindow?.removeGestureRecognizer(recognizer)
            window.addGestureRecognizer(recognizer)
            installedWindow = window
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView || current is UIControl {
                    return false
                }
                view = current.superview
            }
            return true
        }

        @objc private func dismissKeyboard() {
            installedWindow?.endEditing(true)
        }
    }
}
