//
//  PageSettings.swift
//  image2pdf
//
//  Value types describing how the PDF pages should be laid out.
//

import CoreGraphics
import Foundation

/// Paper size measured in PDF points (1 pt = 1/72 inch).
enum PageSize: String, CaseIterable, Identifiable {
    case a4
    case letter
    case fitImage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a4: return "A4"
        case .letter: return "Letter"
        case .fitImage: return "Fit image"
        }
    }

    /// Portrait dimensions in points. `fitImage` has no fixed size and
    /// returns nil so the generator can size each page to its image.
    var portraitSize: CGSize? {
        switch self {
        case .a4: return CGSize(width: 595.2, height: 841.8)
        case .letter: return CGSize(width: 612, height: 792)
        case .fitImage: return nil
        }
    }
}

enum PageOrientation: String, CaseIterable, Identifiable {
    /// Pick portrait or landscape per page, whichever fits the images with the
    /// least wasted whitespace.
    case auto
    case portrait
    case landscape

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "自動"
        case .portrait: return "縦"
        case .landscape: return "横"
        }
    }
}

/// Where each image sits inside its cell when it doesn't fill the cell, i.e.
/// which way the leftover whitespace is pushed.
enum ImageAlignment: String, CaseIterable, Identifiable {
    case center
    case topLeft
    case top
    case left

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .center: return "中央"
        case .topLeft: return "左上"
        case .top: return "上"
        case .left: return "左"
        }
    }

    /// Horizontal/vertical anchor factors: 0 = leading/top, 0.5 = center, 1 = trailing/bottom.
    var anchor: (horizontal: CGFloat, vertical: CGFloat) {
        switch self {
        case .center: return (0.5, 0.5)
        case .topLeft: return (0, 0)
        case .top: return (0.5, 0)
        case .left: return (0, 0.5)
        }
    }
}

/// How many images are placed on a single page, and the grid used to arrange them.
enum PageLayout: Int, CaseIterable, Identifiable {
    case one = 1
    case two = 2
    case four = 4
    case six = 6
    case eight = 8

    var id: Int { rawValue }

    var imagesPerPage: Int { rawValue }

    var displayName: String {
        rawValue == 1 ? "1 per page" : "\(rawValue) per page"
    }

    /// Base grid expressed for a portrait page (rows >= cols).
    private var portraitGrid: (rows: Int, cols: Int) {
        switch self {
        case .one: return (1, 1)
        case .two: return (2, 1)
        case .four: return (2, 2)
        case .six: return (3, 2)
        case .eight: return (4, 2)
        }
    }

    /// Grid adapted to the page orientation so cells stay close to square.
    func grid(for orientation: PageOrientation) -> (rows: Int, cols: Int) {
        let base = portraitGrid
        guard rawValue > 1, orientation == .landscape else { return base }
        return (base.cols, base.rows)
    }
}
