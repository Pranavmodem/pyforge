import Foundation
import ImageIO

func props(_ path: String) -> [CFString: Any] {
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
}

let source = props(CommandLine.arguments[1])
let output = props(CommandLine.arguments[2])
let before = source[kCGImagePropertyExifDictionary] as? [CFString: Any]
let after = output[kCGImagePropertyExifDictionary] as? [CFString: Any]
precondition(before?[kCGImagePropertyExifUserComment] as? String == "fixture-metadata-marker")
precondition(after?[kCGImagePropertyExifUserComment] == nil)
precondition(output[kCGImagePropertyPixelWidth] as? Int == 300)
precondition(output[kCGImagePropertyPixelHeight] as? Int == 300)
