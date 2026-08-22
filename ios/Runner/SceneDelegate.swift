import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var privacyOverlay: UIVisualEffectView?

  override func sceneWillResignActive(_ scene: UIScene) {
    guard let window else { return }
    let overlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    overlay.frame = window.bounds
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
