import UIKit
import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import ScreenshotKit

/// Entry point for the Share Extension. Loads the shared image, then hosts the
/// SwiftUI capture modal. On save/cancel it dismisses the extension, returning
/// the user to the app they were in.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        loadSharedImage { [weak self] image in
            self?.presentModal(with: image)
        }
    }

    private func presentModal(with image: UIImage?) {
        let container = DataStore.resolvedContainer().container

        let root = CaptureModalView(
            image: image,
            onComplete: { [weak self] in self?.finish() },
            onCancel: { [weak self] in self?.finish() }
        )
        .modelContainer(container)

        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    /// Pull the first image attachment from the share context.
    private func loadSharedImage(completion: @escaping (UIImage?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first,
              provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        else { completion(nil); return }

        provider.loadItem(forTypeIdentifier: UTType.image.identifier) { data, _ in
            var image: UIImage?
            if let url = data as? URL, let d = try? Data(contentsOf: url) { image = UIImage(data: d) }
            else if let d = data as? Data { image = UIImage(data: d) }
            else if let img = data as? UIImage { image = img }
            DispatchQueue.main.async { completion(image) }
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
