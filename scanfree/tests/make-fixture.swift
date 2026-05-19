import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
for (name, text) in [("page-one", "Portfolio document one"), ("page-two", "Transfer record two")] {
    let width = 960
    let height = 640
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    (text as NSString).draw(at: CGPoint(x: 90, y: 320), withAttributes: [
        .font: NSFont.systemFont(ofSize: 56), .foregroundColor: NSColor.black
    ])
    let url = folder.appendingPathComponent(name + ".jpg")
    let writer = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    let exif = [kCGImagePropertyExifUserComment: "fixture-metadata-marker"]
    CGImageDestinationAddImage(writer, context.makeImage()!, [kCGImagePropertyExifDictionary: exif] as CFDictionary)
    precondition(CGImageDestinationFinalize(writer))
}
