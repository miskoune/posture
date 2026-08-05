import AppKit
import AVFoundation

/// Hosts the preview layer, the face box drawn over it, and a dashed guide
/// line at the calibrated head height. Shared by the dashboard's big preview
/// and the corner panel a nudge brings up.
final class PreviewView: NSView {
    let previewLayer: AVCaptureVideoPreviewLayer
    private let faceLayer = CAShapeLayer()
    private let guideLayer = CAShapeLayer()

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)

        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect

        faceLayer.fillColor = nil
        faceLayer.lineWidth = 3
        faceLayer.lineJoin = .round

        guideLayer.fillColor = nil
        guideLayer.lineWidth = 1.5
        guideLayer.lineDashPattern = [6, 6]
        guideLayer.strokeColor = NSColor.white.withAlphaComponent(0.6).cgColor

        layer?.addSublayer(previewLayer)
        layer?.addSublayer(guideLayer)
        layer?.addSublayer(faceLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        faceLayer.frame = bounds
        guideLayer.frame = bounds
        CATransaction.commit()
    }

    /// `faceBox` in Vision's normalised coordinates; `guideHeight` is the
    /// calibrated head height (the baseline's uprightness), or nil before
    /// calibration.
    func drawFace(_ faceBox: CGRect, guideHeight: Double?, color: NSColor) {
        // The preview conversion is axis-aligned, so two opposite corners
        // are enough to rebuild the rectangle, mirrored and fitted.
        let a = convert(CGPoint(x: faceBox.minX, y: faceBox.minY))
        let b = convert(CGPoint(x: faceBox.maxX, y: faceBox.maxY))
        let rect = CGRect(
            x: min(a.x, b.x), y: min(a.y, b.y),
            width: abs(b.x - a.x), height: abs(b.y - a.y)
        )
        let face = CGPath(
            roundedRect: rect,
            cornerWidth: min(12, rect.width / 4),
            cornerHeight: min(12, rect.height / 4),
            transform: nil
        )

        let guide = CGMutablePath()
        if let guideHeight {
            let y = convert(CGPoint(x: 0.5, y: guideHeight)).y
            guide.move(to: CGPoint(x: 0, y: y))
            guide.addLine(to: CGPoint(x: bounds.width, y: y))
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        faceLayer.path = face
        faceLayer.strokeColor = color.cgColor
        guideLayer.path = guide
        CATransaction.commit()
    }

    func clear() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        faceLayer.path = nil
        guideLayer.path = nil
        CATransaction.commit()
    }

    /// Vision's origin is bottom-left; the preview layer wants capture-device
    /// coordinates with origin top-left, and hands back a point that already
    /// accounts for aspect fitting and mirroring.
    private func convert(_ visionPoint: CGPoint) -> CGPoint {
        previewLayer.layerPointConverted(
            fromCaptureDevicePoint: CGPoint(x: visionPoint.x, y: 1 - visionPoint.y)
        )
    }
}
