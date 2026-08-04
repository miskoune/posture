import CoreVideo
import Foundation
import PostureCore
import Vision

/// Turns one camera frame into a `Reading`, using Vision's body pose model.
///
/// The only place in the app that knows what a pixel is. Nothing is written to
/// disk here — the buffer is measured and handed straight back to AVFoundation.
struct PoseReader {
    /// Below this, Vision is guessing. Better to report "cannot see you" than
    /// to nudge someone because a coat rack looked like a shoulder.
    private let minimumConfidence: VNConfidence = 0.3

    /// A shoulder line narrower than this is a bad detection, not a person
    /// sitting very far away.
    private let minimumShoulderWidth = 0.02

    func read(_ pixelBuffer: CVPixelBuffer) -> SensorOutcome {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return .unavailable(reason: "Vision failed: \(error.localizedDescription)")
        }

        guard let observation = request.results?.first,
              let joints = try? observation.recognizedPoints(.all) else {
            return .noPersonVisible
        }

        return measure(joints)
    }

    private func measure(
        _ joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    ) -> SensorOutcome {
        guard let nose = joints[.nose],
              let leftShoulder = joints[.leftShoulder],
              let rightShoulder = joints[.rightShoulder],
              nose.confidence >= minimumConfidence,
              leftShoulder.confidence >= minimumConfidence,
              rightShoulder.confidence >= minimumConfidence else {
            return .noPersonVisible
        }

        let dx = Double(leftShoulder.location.x - rightShoulder.location.x)
        let dy = Double(leftShoulder.location.y - rightShoulder.location.y)
        let shoulderWidth = (dx * dx + dy * dy).squareRoot()
        guard shoulderWidth >= minimumShoulderWidth else { return .noPersonVisible }

        // Vision's origin is bottom-left, so a higher head means a larger y.
        let shoulderMidY = Double(leftShoulder.location.y + rightShoulder.location.y) / 2
        let headHeight = Double(nose.location.y) - shoulderMidY

        return .measured(
            Reading(uprightness: headHeight / shoulderWidth, proximity: shoulderWidth)
        )
    }
}
