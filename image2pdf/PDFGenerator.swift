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
        /// Where each image sits inside its cell when it doesn't fill it.
        var alignment: ImageAlignment = .center
    }

    /// Builds PDF data from the given images. Returns nil when there are no images.
    static func makePDF(from images: [UIImage], options: Options) -> Data? {
        guard !images.isEmpty else { return nil }

        let perPage = options.layout.imagesPerPage

        // Placeholder bounds for the renderer; the real bounds are set per page
        // since each page may have its own orientation (Auto) or size (Fit image).
        let defaultRect = CGRect(origin: .zero,
                                 size: pageSize(for: options,
                                                orientation: resolvedOrientation(options.orientation),
                                                sampleImage: images.first))

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

                // Decide this page's orientation (Auto picks the one with the
                // least whitespace) and derive its grid and bounds from it.
                let orientation = bestOrientation(for: pageImages, options: options)
                let (rows, cols) = options.layout.grid(for: orientation)
                let pageRect = pageRectForPage(firstImage: pageImages.first,
                                               options: options,
                                               orientation: orientation)

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
                     showImageNumbers: options.showImageNumbers,
                     alignment: options.alignment)

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

    // MARK: - Orientation

    /// Falls back to portrait when the orientation is `.auto`; used when a
    /// concrete orientation is needed but no images are available to evaluate.
    private static func resolvedOrientation(_ orientation: PageOrientation) -> PageOrientation {
        orientation == .auto ? .portrait : orientation
    }

    /// Returns the orientation to use for a page. For `.auto`, evaluates both
    /// portrait and landscape and keeps the one that lets the images cover more
    /// of the page (i.e. leaves the least whitespace).
    private static func bestOrientation(for images: [UIImage], options: Options) -> PageOrientation {
        guard options.orientation == .auto else { return options.orientation }
        // Fit-image pages already hug the image, so orientation is irrelevant.
        guard options.pageSize.portraitSize != nil else { return .portrait }

        let portrait = coverage(of: images, options: options, orientation: .portrait)
        let landscape = coverage(of: images, options: options, orientation: .landscape)
        return landscape > portrait ? .landscape : .portrait
    }

    /// Total drawn image area for a given orientation. Higher means less wasted
    /// whitespace. Page area is identical between portrait and landscape for a
    /// fixed paper size, so comparing summed areas is a fair measure.
    private static func coverage(of images: [UIImage],
                                 options: Options,
                                 orientation: PageOrientation) -> CGFloat {
        let pageRect = CGRect(origin: .zero,
                              size: pageSize(for: options, orientation: orientation, sampleImage: images.first))
        let (rows, cols) = options.layout.grid(for: orientation)
        let cell = cellSize(in: pageRect, rows: rows, cols: cols,
                            margin: options.margin, spacing: options.spacing)
        let cellRect = CGRect(origin: .zero, size: cell)

        return images.reduce(0) { sum, image in
            let target = aspectFitRect(for: image.pixelSize, in: cellRect)
            return sum + target.width * target.height
        }
    }

    // MARK: - Page sizing

    private static func pageSize(for options: Options,
                                 orientation: PageOrientation,
                                 sampleImage: UIImage?) -> CGSize {
        if let size = options.pageSize.portraitSize {
            return orientation == .landscape
                ? CGSize(width: size.height, height: size.width)
                : size
        }
        // Fit-image mode: use the sample image's pixel size, with a sane fallback.
        let imageSize = sampleImage?.pixelSize ?? CGSize(width: 595.2, height: 841.8)
        return imageSize
    }

    private static func pageRectForPage(firstImage: UIImage?,
                                        options: Options,
                                        orientation: PageOrientation) -> CGRect {
        let size = pageSize(for: options, orientation: orientation, sampleImage: firstImage)
        return CGRect(origin: .zero, size: size)
    }

    /// Size of a single grid cell within the page's content area.
    private static func cellSize(in pageRect: CGRect,
                                 rows: Int,
                                 cols: Int,
                                 margin: CGFloat,
                                 spacing: CGFloat) -> CGSize {
        let contentWidth = max(pageRect.width - margin * 2, 1)
        let contentHeight = max(pageRect.height - margin * 2, 1)
        let cellWidth = (contentWidth - spacing * CGFloat(cols - 1)) / CGFloat(cols)
        let cellHeight = (contentHeight - spacing * CGFloat(rows - 1)) / CGFloat(rows)
        return CGSize(width: cellWidth, height: cellHeight)
    }

    // MARK: - Drawing

    private static func draw(images: [UIImage],
                             in pageRect: CGRect,
                             rows: Int,
                             cols: Int,
                             margin: CGFloat,
                             spacing: CGFloat,
                             startIndex: Int,
                             showImageNumbers: Bool,
                             alignment: ImageAlignment) {
        let cell = cellSize(in: pageRect, rows: rows, cols: cols, margin: margin, spacing: spacing)
        let cellWidth = cell.width
        let cellHeight = cell.height

        for (i, image) in images.enumerated() {
            let row = i / cols
            let col = i % cols

            let cellX = margin + CGFloat(col) * (cellWidth + spacing)
            let cellY = margin + CGFloat(row) * (cellHeight + spacing)
            let cell = CGRect(x: cellX, y: cellY, width: cellWidth, height: cellHeight)

            let target = aspectFitRect(for: image.pixelSize, in: cell, alignment: alignment)
            image.draw(in: target)

            // Overlaid on top of the image; does not affect the image size.
            if showImageNumbers {
                drawImageNumberBadge(startIndex + i + 1, in: target)
            }
        }
    }

    /// Draws a small numbered badge in the bottom-right corner of an image so the
    /// reading order is obvious even with several images on one page. The badge
    /// is drawn over the image and never changes its size.
    private static func drawImageNumberBadge(_ number: Int, in imageRect: CGRect) {
        let text = "\(number)" as NSString
        let fontSize = max(7, min(imageRect.width, imageRect.height) * 0.045)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]

        let textSize = text.size(withAttributes: attributes)
        let padding = fontSize * 0.3
        let badgeSize = max(textSize.width, textSize.height) + padding * 2
        let inset = fontSize * 0.35
        let badgeRect = CGRect(x: imageRect.maxX - inset - badgeSize,
                               y: imageRect.maxY - inset - badgeSize,
                               width: badgeSize,
                               height: badgeSize)

        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: badgeSize * 0.25)
        UIColor.black.withAlphaComponent(0.3).setFill()
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
    /// aspect ratio, anchoring the result according to `alignment` (which side
    /// the leftover whitespace is pushed to). Defaults to centering.
    private static func aspectFitRect(for imageSize: CGSize,
                                      in bounds: CGRect,
                                      alignment: ImageAlignment = .center) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let (hAnchor, vAnchor) = alignment.anchor
        let x = bounds.minX + (bounds.width - width) * hAnchor
        let y = bounds.minY + (bounds.height - height) * vAnchor
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
