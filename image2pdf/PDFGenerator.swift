//
//  PDFGenerator.swift
//  image2pdf
//
//  Renders an array of images into a single PDF document.
//

import PDFKit
import UIKit

enum PDFGenerator {

    struct Options {
        var pageSize: PageSize = .a4
        var orientation: PageOrientation = .portrait
        var layout: PageLayout = .one
        /// Outer page margin in points.
        var margin: CGFloat = 24
        /// Gap between cells in points.
        var spacing: CGFloat = 12
        var backgroundColor: UIColor = .white
        /// Draw a small page number in the bottom-right corner of each page.
        var showPageNumbers: Bool = true
        /// Draw a small sequence-number badge on each image so the order stays
        /// clear even when several photos share a page.
        var showImageNumbers: Bool = true
    }

    /// Builds PDF data from the given images. Returns nil when there are no images.
    static func makePDF(from images: [UIImage], options: Options) -> Data? {
        guard !images.isEmpty else { return nil }

        let perPage = options.layout.imagesPerPage
        let (rows, cols) = options.layout.grid(for: options.orientation)

        // Default page rect. For `.fitImage` each page is sized individually,
        // so this initial bounds is just a placeholder that we override per page.
        let defaultRect = CGRect(origin: .zero, size: pageSize(for: options, sampleImage: images.first))

        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: defaultRect, format: format)

        let totalPages = (images.count + perPage - 1) / perPage

        let data = renderer.pdfData { context in
            var index = 0
            var pageNumber = 0
            while index < images.count {
                let upper = min(index + perPage, images.count)
                let pageImages = Array(images[index..<upper])
                pageNumber += 1

                let pageRect = pageRectForPage(firstImage: pageImages.first,
                                               options: options,
                                               fallback: defaultRect)

                context.beginPage(withBounds: pageRect, pageInfo: [:])

                options.backgroundColor.setFill()
                context.fill(pageRect)

                draw(images: pageImages,
                     in: pageRect,
                     rows: rows,
                     cols: cols,
                     margin: options.margin,
                     spacing: options.spacing,
                     startIndex: index,
                     showImageNumbers: options.showImageNumbers)

                // Drawn last so it sits on top, and computed independently of the
                // image cells so it never changes the printed image sizes.
                if options.showPageNumbers {
                    drawPageNumber(pageNumber, of: totalPages, in: pageRect)
                }

                index = upper
            }
        }
        return data
    }

    // MARK: - Page sizing

    private static func pageSize(for options: Options, sampleImage: UIImage?) -> CGSize {
        if let size = options.pageSize.portraitSize {
            return options.orientation == .portrait
                ? size
                : CGSize(width: size.height, height: size.width)
        }
        // Fit-image mode: use the sample image's pixel size, with a sane fallback.
        let imageSize = sampleImage?.pixelSize ?? CGSize(width: 595.2, height: 841.8)
        return imageSize
    }

    private static func pageRectForPage(firstImage: UIImage?,
                                        options: Options,
                                        fallback: CGRect) -> CGRect {
        guard options.pageSize == .fitImage else { return fallback }
        let size = pageSize(for: options, sampleImage: firstImage)
        return CGRect(origin: .zero, size: size)
    }

    // MARK: - Drawing

    private static func draw(images: [UIImage],
                             in pageRect: CGRect,
                             rows: Int,
                             cols: Int,
                             margin: CGFloat,
                             spacing: CGFloat,
                             startIndex: Int,
                             showImageNumbers: Bool) {
        let contentWidth = max(pageRect.width - margin * 2, 1)
        let contentHeight = max(pageRect.height - margin * 2, 1)

        let cellWidth = (contentWidth - spacing * CGFloat(cols - 1)) / CGFloat(cols)
        let cellHeight = (contentHeight - spacing * CGFloat(rows - 1)) / CGFloat(rows)

        for (i, image) in images.enumerated() {
            let row = i / cols
            let col = i % cols

            let cellX = margin + CGFloat(col) * (cellWidth + spacing)
            let cellY = margin + CGFloat(row) * (cellHeight + spacing)
            let cell = CGRect(x: cellX, y: cellY, width: cellWidth, height: cellHeight)

            let target = aspectFitRect(for: image.pixelSize, in: cell)
            image.draw(in: target)

            // Overlaid on top of the image; does not affect the image size.
            if showImageNumbers {
                drawImageNumberBadge(startIndex + i + 1, in: target)
            }
        }
    }

    /// Draws a small numbered badge in the top-left corner of an image so the
    /// reading order is obvious even with several images on one page. The badge
    /// is drawn over the image and never changes its size.
    private static func drawImageNumberBadge(_ number: Int, in imageRect: CGRect) {
        let text = "\(number)" as NSString
        let fontSize = max(9, min(imageRect.width, imageRect.height) * 0.07)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor.white
        ]

        let textSize = text.size(withAttributes: attributes)
        let padding = fontSize * 0.4
        let badgeSize = max(textSize.width, textSize.height) + padding * 2
        let inset = fontSize * 0.4
        let badgeRect = CGRect(x: imageRect.minX + inset,
                               y: imageRect.minY + inset,
                               width: badgeSize,
                               height: badgeSize)

        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: badgeSize * 0.25)
        UIColor.black.withAlphaComponent(0.55).setFill()
        badgePath.fill()

        let textOrigin = CGPoint(x: badgeRect.midX - textSize.width / 2,
                                 y: badgeRect.midY - textSize.height / 2)
        text.draw(at: textOrigin, withAttributes: attributes)
    }

    /// Draws a small "page / total" label in the bottom-right corner. This is
    /// overlaid on top of the page and uses a fixed inset from the page edges,
    /// so it is completely independent of the image layout and never alters the
    /// size or position of the printed images.
    private static func drawPageNumber(_ page: Int, of total: Int, in pageRect: CGRect) {
        let text = "\(page) / \(total)" as NSString
        let fontSize = max(8, min(pageRect.width, pageRect.height) * 0.018)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.gray
        ]

        let textSize = text.size(withAttributes: attributes)
        let inset: CGFloat = fontSize
        let origin = CGPoint(x: pageRect.maxX - inset - textSize.width,
                             y: pageRect.maxY - inset - textSize.height)
        text.draw(at: origin, withAttributes: attributes)
    }

    /// Returns the rect that fits `imageSize` inside `bounds` while preserving
    /// aspect ratio and centering the result.
    private static func aspectFitRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let x = bounds.midX - width / 2
        let y = bounds.midY - height / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private extension UIImage {
    /// Size in points adjusted for the image scale so EXIF/Retina images
    /// keep their true aspect ratio when drawn into a PDF.
    var pixelSize: CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }
}
