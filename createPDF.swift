import Foundation
import Quartz

func createPDF(from imageURLs: [URL], outputURL: URL) -> Bool {
    let pdfDocument = PDFDocument()
    
    for (index, imageURL) in imageURLs.enumerated() {
        guard let image = NSImage(contentsOf: imageURL),
              let page = PDFPage(image: image) else {
            continue
        }
        pdfDocument.insert(page, at: index)
    }
    
    return pdfDocument.write(to: outputURL)
}

let args = CommandLine.arguments.dropFirst()
guard args.count >= 2 else {
    print("Usage: \(CommandLine.arguments[0]) output.pdf image1.jpg [image2.png ...]")
    exit(1)
}

let outputURL = URL(fileURLWithPath: args.first!)
let imageURLs = args.dropFirst().map { URL(fileURLWithPath: $0) }

let success = createPDF(from: Array(imageURLs), outputURL: outputURL)
exit(success ? 0 : 1)
