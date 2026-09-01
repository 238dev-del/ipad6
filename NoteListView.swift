import SwiftUI
import PencilKit
import PhotosUI

struct NoteListView: View {
    @EnvironmentObject var store: NoteStore
    @State private var search = ""
    @State private var newNote: Note?

    var filtered: [Note] {
        search.isEmpty ? store.notes : store.notes.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filtered) { n in
                    NavigationLink(destination: NoteEditorView(note: n).environmentObject(store)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(n.title).font(.headline)
                            Text("\(n.pages.count) หน้า · \(n.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { $0.forEach { store.delete(filtered[$0]) } }
            }
            .searchable(text: $search, prompt: "ค้นหาโน้ต")
            .navigationTitle("โน้ตของฉัน")
            .toolbar {
                Button { newNote = store.createNote() } label: { Image(systemName: "square.and.pencil") }
            }
            .background(
                NavigationLink(isActive: Binding(get: { newNote != nil }, set: { if !$0 { newNote = nil } })) {
                    if let n = newNote { NoteEditorView(note: n).environmentObject(store) }
                } label: { EmptyView() }
            )
        }
        .navigationViewStyle(.stack)
    }
}

enum PDFExporter {
    static func export(note: Note, size: CGSize) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(note.title).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))
        do {
            try renderer.writePDF(to: url) { ctx in
                for page in note.pages {
                    ctx.beginPage()
                    UIColor.white.setFill()
                    UIRectFill(CGRect(origin: .zero, size: size))
                    if let d = page.backgroundImage, let img = UIImage(data: d) {
                        img.draw(in: CGRect(origin: .zero, size: size))
                    }
                    page.drawing.image(from: CGRect(origin: .zero, size: size), scale: 2)
                        .draw(in: CGRect(origin: .zero, size: size))
                }
            }
            return url
        } catch { return nil }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct PhotoPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(); cfg.filter = .images
        let vc = PHPickerViewController(configuration: cfg)
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> C { C(onPick) }
    final class C: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void
        init(_ f: @escaping (UIImage) -> Void) { onPick = f }
        func picker(_ p: PHPickerViewController, didFinishPicking r: [PHPickerResult]) {
            p.dismiss(animated: true)
            r.first?.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                if let img = obj as? UIImage { DispatchQueue.main.async { self.onPick(img) } }
            }
        }
    }
}
