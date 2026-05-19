import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Vision

enum ScanError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        switch self { case .invalid(let message): return message }
    }
}

func pageImage(_ path: String) throws -> CGImage {
    let url = URL(fileURLWithPath: path)
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 2800
    ]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        throw ScanError.invalid("could not decode \(url.lastPathComponent)")
    }
    return image
}

func recognize(_ image: CGImage) throws -> [VNRecognizedTextObservation] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    return request.results ?? []
}

func addText(_ observations: [VNRecognizedTextObservation], to context: CGContext, page: CGRect) {
    let ordered = observations.sorted {
        let left = Int($0.boundingBox.midY * 100)
        let right = Int($1.boundingBox.midY * 100)
        return left == right ? $0.boundingBox.minX < $1.boundingBox.minX : left > right
    }
    for observation in ordered {
        guard let text = observation.topCandidates(1).first?.string, !text.isEmpty else { continue }
        let box = observation.boundingBox
        let size = max(1, box.height * page.height * 0.85)
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        guard width > 0, box.width > 0 else { continue }
        context.saveGState()
        context.translateBy(x: box.minX * page.width, y: box.minY * page.height + size * 0.15)
        context.scaleBy(x: box.width * page.width / width, y: 1)
        context.textMatrix = .identity
        context.textPosition = .zero
        context.setTextDrawingMode(.invisible)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

func monochrome(_ image: CGImage) throws -> CGImage {
    guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
        throw ScanError.invalid("could not create grayscale page")
    }
    let frame = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(frame)
    context.draw(image, in: frame)
    guard let gray = context.makeImage() else { throw ScanError.invalid("could not render grayscale page") }
    return gray
}

func scan(arguments: [String]) throws {
    let grayscale = arguments.first == "--grayscale"
    let paths = grayscale ? Array(arguments.dropFirst()) : arguments
    guard (2...101).contains(paths.count) else {
        throw ScanError.invalid("usage: scanfree [--grayscale] OUTPUT.pdf PAGE_IMAGE [PAGE_IMAGE ...]")
    }
    let output = URL(fileURLWithPath: paths[0]).standardizedFileURL.resolvingSymlinksInPath()
    guard output.pathExtension.lowercased() == "pdf",
          !paths.dropFirst().contains(where: {
              URL(fileURLWithPath: $0).standardizedFileURL.resolvingSymlinksInPath() == output
          }) else {
        throw ScanError.invalid("output must be a PDF path distinct from the input images")
    }
    let bytes = NSMutableData()
    guard let sink = CGDataConsumer(data: bytes as CFMutableData),
          let context = CGContext(consumer: sink, mediaBox: nil, nil) else {
        throw ScanError.invalid("could not start PDF output")
    }

    for path in paths.dropFirst() {
        let decoded = try pageImage(path)
        let image = try grayscale ? monochrome(decoded) : decoded
        let text = try recognize(image)
        let scale = 612 / CGFloat(image.width)
        let page = CGRect(x: 0, y: 0, width: 612, height: CGFloat(image.height) * scale)
        var box = page
        let pageInfo = [kCGPDFContextMediaBox: Data(bytes: &box, count: MemoryLayout<CGRect>.size)]
        context.beginPDFPage(pageInfo as CFDictionary)
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(page)
        context.draw(image, in: page)
        addText(text, to: context, page: page)
        context.endPDFPage()
    }
    context.closePDF()
    try (bytes as Data).write(to: output, options: .atomic)
}

do {
    try scan(arguments: Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data("scanfree: \(error)\n".utf8))
    exit(2)
}
