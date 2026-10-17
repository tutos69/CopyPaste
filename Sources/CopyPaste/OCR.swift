import AppKit
import Vision

/// On-device text recognition using Apple's Vision framework (no internet needed).
enum OCR {
    static func recognizeText(in data: Data, completion: @escaping (String) -> Void) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            completion("")
            return
        }
        recognizeText(in: image, completion: completion)
    }

    static func recognizeText(in image: CGImage, completion: @escaping (String) -> Void) {
        let request = VNRecognizeTextRequest { request, _ in
            let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async { completion(text) }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["es-ES", "en-US"]

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try VNImageRequestHandler(cgImage: image).perform([request])
            } catch {
                DispatchQueue.main.async { completion("") }
            }
        }
    }
}
