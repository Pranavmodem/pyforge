import Foundation
import PDFKit

let document = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1]))!
precondition(document.pageCount == 2)
precondition(document.page(at: 0)?.string?.contains("Portfolio document one") == true)
precondition(document.page(at: 1)?.string?.contains("Transfer record two") == true)
