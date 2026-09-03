import CarPlay

/// CarPlay face: native templates (Apple mandate — no webviews in the car).
/// Browsing runs against the shared AppModel's cached catalog, so the car UI
/// works the moment the phone has synced once.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var browseController: CarPlayBrowseController?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        let model = AppModel.shared
        model.start()
        let browse = CarPlayBrowseController(interfaceController: interfaceController,
                                             model: model)
        browseController = browse
        interfaceController.setRootTemplate(browse.makeRootTemplate(),
                                            animated: false, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.browseController = nil
    }
}
