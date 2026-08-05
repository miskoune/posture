import CoreGraphics
import CoreVideo
import Foundation
import PostureCore
import Vision

/// Where the face was found, in Vision's normalised coordinates (origin
/// bottom-left). Only the preview window wants this; the monitor keeps
/// receiving a bare `Reading`.
struct PoseSnapshot {
    let faceBox: CGRect
    let reading: Reading
}

/// What one frame contained, with enough detail to draw it.
enum PoseDetection {
    case pose(PoseSnapshot)
    case nobody
    case failed(String)
}

/// Turns one camera frame into a `Reading`, using Vision's face detector.
///
/// The only place in the app that knows what a pixel is. Nothing is written to
/// disk here — the buffer is measured and handed straight back to AVFoundation.
///
/// Face detection, not body pose: Vision's body-pose model wants most of a
/// body in frame and returns nothing at all for the head-and-shoulders crop a
/// desk webcam actually sees. The face detector is dependable at exactly that
/// distance, and a face box carries both signals a slouch produces — the head
/// sinking (box drops) and the body leaning in (box grows).
struct PoseReader {
    /// Below this, Vision is guessing. Better to report "cannot see you" than
    /// to nudge someone because a poster looked like a face.
    private let minimumConfidence: VNConfidence = 0.5

    /// A face narrower than this is a bad detection or someone across the
    /// room, not the person at the desk.
    private let minimumFaceWidth = 0.04

    func read(_ pixelBuffer: CVPixelBuffer) -> SensorOutcome {
        switch detect(pixelBuffer) {
        case .pose(let snapshot):
            return .measured(snapshot.reading)
        case .nobody:
            return .noPersonVisible
        case .failed(let reason):
            return .unavailable(reason: reason)
        }
    }

    func detect(_ pixelBuffer: CVPixelBuffer) -> PoseDetection {
        let request = VNDetectFaceRectanglesRequest()
        // Revision 3 is the one that reports head pitch alongside roll; the
        // default revision depends on the OS, so pin it.
        request.revision = VNDetectFaceRectanglesRequestRevision3
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return .failed("Vision failed: \(error.localizedDescription)")
        }

        // The largest confident face is the person at the desk; anyone
        // walking past in the background is smaller.
        let candidates = (request.results ?? [])
            .filter { $0.confidence >= minimumConfidence }
        guard let face = candidates.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
              face.boundingBox.width >= minimumFaceWidth else {
            return .nobody
        }

        let box = face.boundingBox
        return .pose(PoseSnapshot(
            faceBox: box,
            reading: Reading(
                uprightness: Double(box.midY),
                proximity: Double(box.width),
                pitch: face.pitch?.doubleValue ?? 0,
                roll: face.roll?.doubleValue ?? 0
            )
        ))
    }
}
