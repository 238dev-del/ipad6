import SwiftUI
import PencilKit

enum ToolKind: String, CaseIterable { case pen, pencil, marker, eraser, lasso
    var icon: String {
        switch self {
        case .pen: return "pencil.tip"; case .pencil: return "pencil"
        case .marker: return "highlighter"; case .eraser: return "eraser"
        case .lasso: return "lasso"
        }
    }
}

struct NoteEditorView: View {
    @EnvironmentObject var store: NoteStore
    @State var note: Note
    @StateObject private var controller = CanvasController()

    @State private var pageIndex = 0
    @State private var kind: ToolKind = .pen
    @State private var color: Color = .black
    @State private var width: CGFloat = 4
    @State private var palmRejection = true
    @State private var showPhotoPicker = false
    @State private var showExport = false
    @State private var exportURL: URL?
    @State private var saveTimer: Timer?

    private let pageSize = CGSize(width: 794, height: 1123)   // A4
    private let palette: [Color] = [.black, .blue, .red, .green, .orange, .purple, .brown, .gray]

    private var tool: PKTool {
        let c = UIColor(color)
        switch kind {
        case .pen:    return PKInkingTool(.pen, color: c, width: width)
        case .pencil: return PKInkingTool(.pencil, color: c, width: width)
        case .marker: return PKInkingTool(.marker, color: c.withAlphaComponent(0.4), width: width * 5)
        case .eraser: return PKEraserTool(.bitmap)
        case .lasso:  return PKLassoTool()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            CanvasView(drawing: bindingDrawing,
                       tool: tool,
                       template: note.template,
                       photo: note.pages[pageIndex].backgroundImage.flatMap(UIImage.init(data:)),
                       palmRejection: palmRejection,
                       pageSize: pageSize,
                       controller: controller)
                .background(Color(.systemGray5))
            Divider()
            pageBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(note.title)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { menu } }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { img in
                note.pages[pageIndex].backgroundImage = img.jpegData(compressionQuality: 0.7)
                scheduleSave()
            }
        }
        .sheet(isPresented: $showExport) { if let u = exportURL { ShareSheet(items: [u]) } }
        .onDisappear { note = store.save(note) }
    }

    private var bindingDrawing: Binding<PKDrawing> {
        Binding(get: { note.pages[pageIndex].drawing },
                set: { note.pages[pageIndex].drawing = $0; scheduleSave() })
    }

    // MARK: แถบเครื่องมือ
    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(ToolKind.allCases, id: \.self) { t in
                    Button { kind = t } label: {
                        Image(systemName: t.icon)
                            .font(.system(size: 19))
                            .frame(width: 40, height: 34)
                            .background(kind == t ? Color.accentColor.opacity(0.2) : .clear)
                            .cornerRadius(8)
                    }
                }
                Divider().frame(height: 26)
                ForEach(palette, id: \.self) { c in
                    Circle().fill(c).frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.primary, lineWidth: color == c ? 2 : 0))
                        .onTapGesture { color = c; if kind == .eraser { kind = .pen } }
                }
                Divider().frame(height: 26)
                Slider(value: $width, in: 1...20).frame(width: 110)
                Divider().frame(height: 26)
                Button { controller.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                Button { controller.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                Toggle(isOn: $palmRejection) { Image(systemName: "hand.raised.slash") }
                    .toggleStyle(.button).frame(width: 44)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    // MARK: แถบหน้า
    private var pageBar: some View {
        HStack {
            Button { if pageIndex > 0 { pageIndex -= 1 } } label: { Image(systemName: "chevron.left") }
                .disabled(pageIndex == 0)
            Spacer()
            Text("หน้า \(pageIndex + 1) / \(note.pages.count)").font(.footnote)
            Spacer()
            Button {
                if pageIndex < note.pages.count - 1 { pageIndex += 1 }
                else { note.pages.append(NotePage()); pageIndex += 1; scheduleSave() }
            } label: {
                Image(systemName: pageIndex < note.pages.count - 1 ? "chevron.right" : "plus")
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 10)
    }

    private var menu: some View {
        Menu {
            Picker("แม่แบบ", selection: $note.template) {
                ForEach(PageTemplate.allCases) { Text($0.thaiName).tag($0) }
            }
            Button { showPhotoPicker = true } label: { Label("แทรกรูปพื้นหลัง", systemImage: "photo") }
            Button { exportURL = PDFExporter.export(note: note, size: pageSize); showExport = exportURL != nil }
                label: { Label("ส่งออก PDF", systemImage: "square.and.arrow.up") }
            Button(role: .destructive) {
                if note.pages.count > 1 { note.pages.remove(at: pageIndex); pageIndex = max(0, pageIndex - 1); scheduleSave() }
            } label: { Label("ลบหน้านี้", systemImage: "trash") }
        } label: { Image(systemName: "ellipsis.circle") }
    }

    /// บันทึกอัตโนมัติแบบหน่วงเวลา (ถนอมแรง iPad 6)
    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { _ in
            note = store.save(note)
        }
    }
}
