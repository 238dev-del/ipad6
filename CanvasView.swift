import SwiftUI
import PencilKit

/// PKCanvasView ที่พยายามกันฝ่ามือ โดยดูจากขนาดพื้นที่สัมผัส
final class NoteCanvasView: PKCanvasView {
    var palmRejectionEnabled = true
    var radiusThreshold: CGFloat = 20   // ปลายปากกา ~5-12, ฝ่ามือ > 25

    private func isPalm(_ touches: Set<UITouch>) -> Bool {
        guard palmRejectionEnabled else { return false }
        return touches.contains { $0.type == .direct && $0.majorRadius > radiusThreshold }
    }
    override func touchesBegan(_ t: Set<UITouch>, with e: UIEvent?) {
        if isPalm(t) { return }; super.touchesBegan(t, with: e)
    }
    override func touchesMoved(_ t: Set<UITouch>, with e: UIEvent?) {
        if isPalm(t) { return }; super.touchesMoved(t, with: e)
    }
}

/// พื้นหลังแม่แบบกระดาษ (เลื่อน/ซูมไปพร้อมลายเส้น)
final class TemplateBackgroundView: UIView {
    var template: PageTemplate = .lined { didSet { setNeedsDisplay() } }
    var photo: UIImage? { didSet { setNeedsDisplay() } }

    override func draw(_ rect: CGRect) {
        UIColor.systemBackground.setFill()
        UIRectFill(rect)
        photo?.draw(in: bounds)
        guard let ctx = UIGraphicsGetCurrentContext(), template != .blank else { return }
        ctx.setStrokeColor(UIColor.systemGray3.cgColor)
        ctx.setLineWidth(0.7)
        let step: CGFloat = 32
        switch template {
        case .lined:
            var y = step
            while y < bounds.height { ctx.move(to: .init(x: 24, y: y)); ctx.addLine(to: .init(x: bounds.width - 24, y: y)); y += step }
            ctx.strokePath()
        case .grid:
            var v: CGFloat = 0
            while v < bounds.width  { ctx.move(to: .init(x: v, y: 0)); ctx.addLine(to: .init(x: v, y: bounds.height)); v += step }
            var h: CGFloat = 0
            while h < bounds.height { ctx.move(to: .init(x: 0, y: h)); ctx.addLine(to: .init(x: bounds.width, y: h)); h += step }
            ctx.strokePath()
        case .dotted:
            ctx.setFillColor(UIColor.systemGray3.cgColor)
            var y: CGFloat = step
            while y < bounds.height {
                var x: CGFloat = step
                while x < bounds.width { ctx.fillEllipse(in: .init(x: x, y: y, width: 2, height: 2)); x += step }
                y += step
            }
        case .blank: break
        }
    }
}

/// ตัวควบคุมจากฝั่ง SwiftUI (undo / redo / export)
final class CanvasController: ObservableObject {
    weak var canvas: PKCanvasView?
    func undo() { canvas?.undoManager?.undo() }
    func redo() { canvas?.undoManager?.redo() }
    func clear() { canvas?.drawing = PKDrawing() }
}

struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var tool: PKTool
    var template: PageTemplate
    var photo: UIImage?
    var palmRejection: Bool
    var pageSize: CGSize
    var controller: CanvasController

    func makeUIView(context: Context) -> NoteCanvasView {
        let cv = NoteCanvasView()
        cv.delegate = context.coordinator
        cv.drawing = drawing
        cv.drawingPolicy = .anyInput          // ⭐️ ทำให้ปากกา 2-in-1 / นิ้ว วาดได้
        cv.alwaysBounceVertical = true
        cv.backgroundColor = .clear
        cv.isOpaque = false
        cv.minimumZoomScale = 0.4
        cv.maximumZoomScale = 4.0
        cv.contentSize = pageSize

        let bg = TemplateBackgroundView(frame: CGRect(origin: .zero, size: pageSize))
        bg.template = template
        bg.photo = photo
        bg.tag = 99
        cv.insertSubview(bg, at: 0)           // อยู่ใต้ลายเส้น และเลื่อนตาม content

        controller.canvas = cv
        return cv
    }

    func updateUIView(_ cv: NoteCanvasView, context: Context) {
        if cv.drawing != drawing { cv.drawing = drawing }
        cv.tool = tool
        cv.palmRejectionEnabled = palmRejection
        cv.contentSize = pageSize
        if let bg = cv.viewWithTag(99) as? TemplateBackgroundView {
            bg.frame = CGRect(origin: .zero, size: pageSize)
            bg.template = template
            bg.photo = photo
        }
        if !context.coordinator.didFit, cv.bounds.width > 0 {
            context.coordinator.didFit = true
            cv.zoomScale = cv.bounds.width / pageSize.width   // พอดีความกว้างหน้า
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: CanvasView
        var didFit = false
        init(_ p: CanvasView) { parent = p }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
