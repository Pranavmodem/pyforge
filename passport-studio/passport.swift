import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        switch self { case .invalid(let message): return message }
    }
}

func photo(_ path: String) throws -> CGImage {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= 10_000, height <= 10_000,
          width * height <= 40_000_000 else {
        throw PhotoError.invalid("expected an image of at most 40 megapixels")
    }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: max(width, height)
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        throw PhotoError.invalid("image could not be decoded")
    }
    return image
}

func cropBounds(image: CGImage, width: Int, height: Int, supplied: String?) throws -> CGRect {
    let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    if let supplied = supplied {
        let parts = supplied.split(separator: ",", omittingEmptySubsequences: false)
        let values = parts.compactMap { Int($0) }
        guard parts.count == 4, values.count == 4, values[0] >= 0, values[1] >= 0,
              values[2] > 0, values[3] > 0,
              values[2] <= image.width, values[3] <= image.height,
              values[0] <= image.width - values[2], values[1] <= image.height - values[3],
              values[2] * height == values[3] * width else {
            throw PhotoError.invalid("crop must fit the image and match the requested output ratio")
        }
        return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    // Choose the largest centered integer crop with the exact requested aspect ratio.
    func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
    let divisor = gcd(width, height)
    let unitWidth = width / divisor
    let unitHeight = height / divisor
    let scale = min(image.width / unitWidth, image.height / unitHeight)
    guard scale > 0 else { throw PhotoError.invalid("output ratio does not fit this source image") }
    let cropWidth = unitWidth * scale
    let cropHeight = unitHeight * scale
    return CGRect(x: (Int(bounds.width) - cropWidth) / 2, y: (Int(bounds.height) - cropHeight) / 2,
                  width: cropWidth, height: cropHeight)
}

func export(arguments: [String]) throws {
    guard (4...6).contains(arguments.count),
          let width = Int(arguments[2]), let height = Int(arguments[3]),
          (1...4000).contains(width), (1...4000).contains(height),
          let turns = Int(arguments.count >= 5 ? arguments[4] : "0"),
          (0...3).contains(turns) else {
        throw PhotoError.invalid("usage: passport-studio INPUT OUTPUT WIDTH HEIGHT [CLOCKWISE_TURNS [X,Y,W,H]]")
    }
    let input = URL(fileURLWithPath: arguments[0]).standardizedFileURL.resolvingSymlinksInPath()
    let output = URL(fileURLWithPath: arguments[1]).standardizedFileURL.resolvingSymlinksInPath()
    guard input != output else { throw PhotoError.invalid("output must differ from input") }
    let extensionType = output.pathExtension.lowercased()
    guard ["jpg", "jpeg", "png"].contains(extensionType) else {
        throw PhotoError.invalid("output must be JPEG or PNG")
    }

    var source = try photo(input.path)
    if turns > 0 {
        let orientation: CGImagePropertyOrientation = turns == 1 ? .right : turns == 2 ? .down : .left
        let rotated = CIImage(cgImage: source).oriented(orientation)
        guard let image = CIContext().createCGImage(rotated, from: rotated.extent) else {
            throw PhotoError.invalid("image could not be rotated")
        }
        source = image
    }
    let bounds = try cropBounds(image: source, width: width, height: height,
                                supplied: arguments.count == 6 ? arguments[5] : nil)
    guard let cropped = source.cropping(to: bounds),
          let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw PhotoError.invalid("crop could not be rendered")
    }
    let frame = CGRect(x: 0, y: 0, width: width, height: height)
    context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    context.fill(frame)
    context.interpolationQuality = .high
    context.draw(cropped, in: frame)

    let bytes = NSMutableData()
    let png = extensionType == "png"
    let format = png ? UTType.png.identifier : UTType.jpeg.identifier
    guard let image = context.makeImage(),
          let encoder = CGImageDestinationCreateWithData(bytes, format as CFString, 1, nil) else {
        throw PhotoError.invalid("output encoder could not be created")
    }
    let options: [CFString: Any] = png ? [:] : [kCGImageDestinationLossyCompressionQuality: 0.95]
    CGImageDestinationAddImage(encoder, image, options as CFDictionary)
    guard CGImageDestinationFinalize(encoder) else { throw PhotoError.invalid("image could not be encoded") }
    try (bytes as Data).write(to: output, options: .atomic)
}

do {
    try export(arguments: Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data("passport-studio: \(error)\n".utf8))
    exit(2)
}
