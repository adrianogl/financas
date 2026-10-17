import Testing
import UIKit
@testable import Financas

struct AvatarImageResizerTests {
    @Test func cropsAndResizes() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 800), format: format).pngData { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
        }
        let data = try #require(AvatarImageResizer.jpegData(from: source))
        let image = try #require(UIImage(data: data))
        #expect(image.size == CGSize(width: 512, height: 512))
    }

    @Test func rejectsInvalidData() {
        #expect(AvatarImageResizer.jpegData(from: Data("x".utf8)) == nil)
    }
}
