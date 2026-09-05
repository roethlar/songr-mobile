import SwiftUI
import UIKit

final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let model = AppModel.shared
        model.start()
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(
            rootView: RootView().environmentObject(model)
        )
        window.makeKeyAndVisible()
        self.window = window
        #if DEBUG
        // Screenshot harness: landscape can't be scripted via simctl, so the
        // preview flag asks the scene for a landscape geometry directly.
        if UIPreviewHarness.flag("-SongrForceLandscape") {
            windowScene.requestGeometryUpdate(
                .iOS(interfaceOrientations: .landscapeRight))
        } else if UIPreviewHarness.flag("-SongrForcePortrait") {
            windowScene.requestGeometryUpdate(
                .iOS(interfaceOrientations: .portrait))
        }
        #endif
    }
}
