import Foundation
import PencilKit
import UIKit

enum PageTemplate: String, Codable, CaseIterable, Identifiable {
    case blank, lined, grid, dotted
    var id: String { rawValue }
    var thaiName: String {
        switch self {
        case .blank: return "หน้าเปล่า"
        case .lined: return "เส้นบรรทัด"
        case .grid:  return "ตาราง"
        case .dotted:return "จุดไข่ปลา"
        }
    }
}

struct NotePage: Codable, Identifiable {
    var id = UUID()
    var drawingData = Data()
    var backgroundImage: Data? = nil

    var drawing: PKDrawing {
        get { (try? PKDrawing(data: drawingData)) ?? PKDrawing() }
        set { drawingData = newValue.dataRepresentation() }
    }
}

struct Note: Codable, Identifiable {
    var id = UUID()
    var title = "โน้ตใหม่"
    var createdAt = Date()
    var updatedAt = Date()
    var template: PageTemplate = .lined
    var pages: [NotePage] = [NotePage()]
}

final class NoteStore: ObservableObject {
    @Published var notes: [Note] = []

    private let dir: URL = {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notes", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    init() { load() }

    func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir,
                     includingPropertiesForKeys: nil)) ?? []
        notes = files.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Note.self, from: Data(contentsOf: $0)) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func save(_ note: Note) -> Note {
        var n = note
        n.updatedAt = Date()
        if let data = try? JSONEncoder().encode(n) {
            try? data.write(to: dir.appendingPathComponent("\(n.id).json"), options: .atomic)
        }
        if let i = notes.firstIndex(where: { $0.id == n.id }) { notes[i] = n } else { notes.insert(n, at: 0) }
        notes.sort { $0.updatedAt > $1.updatedAt }
        return n
    }

    func delete(_ note: Note) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(note.id).json"))
        notes.removeAll { $0.id == note.id }
    }

    func createNote() -> Note { save(Note()) }
}
