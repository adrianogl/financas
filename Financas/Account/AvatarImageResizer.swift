import UIKit

enum AvatarImageResizer {
    static func jpegData(from data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let side = AvatarConstants.side
        let scale = side / min(image.size.width, image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
            .jpegData(withCompressionQuality: AvatarConstants.jpegQuality) { _ in
                image.draw(in: CGRect(origin: origin, size: drawn))
            }
    }
}
