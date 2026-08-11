import SwiftUI

/// Bridges the AppKit `PreviewView` (camera layer, face box, guide line) into
/// the SwiftUI page. The window controller owns the view and draws on it
/// directly from the capture callback; SwiftUI only places it.
struct CameraPreview: NSViewRepresentable {
    let view: PreviewView

    func makeNSView(context: Context) -> PreviewView { view }
    func updateNSView(_ nsView: PreviewView, context: Context) {}
}
