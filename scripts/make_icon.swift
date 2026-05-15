import AppKit

let resources = "/Users/songguiming/Documents/code/Smart-English Input/SmartEnglish/Resources"

func makeIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1),
                             xRadius: CGFloat(size) * 0.22,
                             yRadius: CGFloat(size) * 0.22)
    NSColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1).setFill()
    path.fill()

    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: CGFloat(size) * 0.55),
        .foregroundColor: NSColor.white
    ]
    let str = NSAttributedString(string: "E", attributes: attrs)
    let strSize = str.size()
    str.draw(at: NSPoint(
        x: (CGFloat(size) - strSize.width) / 2,
        y: CGFloat(size) * 0.52 - strSize.height / 2
    ))

    image.unlockFocus()
    return image
}

let img16 = makeIcon(size: 16)
let img32 = makeIcon(size: 32)

// 保存为 PNG 再用 tiffutil 合并
if let tiff16 = img16.tiffRepresentation,
   let tiff32 = img32.tiffRepresentation {
    let url16 = URL(fileURLWithPath: resources + "/icon_16.png")
    let url32 = URL(fileURLWithPath: resources + "/icon_32.png")
    try? NSBitmapImageRep(data: tiff16)?
        .representation(using: .png, properties: [:])?
        .write(to: url16)
    try? NSBitmapImageRep(data: tiff32)?
        .representation(using: .png, properties: [:])?
        .write(to: url32)
    print("PNGs saved")
}
