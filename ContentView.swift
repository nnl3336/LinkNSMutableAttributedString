//
//  ContentView.swift
//  LinkNSMutableAttributedString
//
//  Created by Yuki Sasaki on 2025/09/06.
//

import SwiftUI
import CoreData
import UIKit


// MARK: - EditViewController
class EditViewController: UIViewController, UITextViewDelegate, UITextPasteDelegate {
    
    var context: NSManagedObjectContext!
    var note: Note?
    
    let textView = UITextView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        textView.frame = view.bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textView.delegate = self
        textView.isEditable = true
        textView.isSelectable = true
        textView.dataDetectorTypes = [.link]
        view.addSubview(textView)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save,
                                                            target: self,
                                                            action: #selector(saveTapped))
        
        loadContent()
        
        
        textView.pasteDelegate = self   // ← 追加
    }
    
    // MARK: - UITextPasteDelegate
    func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting,
                                          transform item: UITextPasteItem) {
            
            let normalColor: UIColor = {
                if traitCollection.userInterfaceStyle == .dark {
                    return .white
                } else {
                    return .black
                }
            }()
            let linkColor = UIColor.systemBlue
            let font = UIFont.systemFont(ofSize: 20)
            
            if item.itemProvider.canLoadObject(ofClass: NSAttributedString.self) {
                // attributedText をそのまま受け取る場合
                item.itemProvider.loadObject(ofClass: NSAttributedString.self) { (object, error) in
                    if let attr = object as? NSAttributedString {
                        let mutable = NSMutableAttributedString(attributedString: attr)
                        
                        // リンク検出
                        let linkedAttr = NSMutableAttributedString.withLinkDetection(from: mutable)
                        
                        // 全体にフォントと通常色
                        linkedAttr.addAttribute(.font, value: font, range: NSRange(location: 0, length: linkedAttr.length))
                        linkedAttr.addAttribute(.foregroundColor, value: normalColor, range: NSRange(location: 0, length: linkedAttr.length))
                        
                        // リンク部分はリンク色
                        linkedAttr.enumerateAttribute(.link, in: NSRange(location: 0, length: linkedAttr.length)) { value, range, _ in
                            if value != nil {
                                linkedAttr.addAttribute(.foregroundColor, value: linkColor, range: range)
                            }
                        }
                        
                        DispatchQueue.main.async {
                            item.setResult(attributedString: linkedAttr)
                        }
                    }
                }
            } else if item.itemProvider.canLoadObject(ofClass: String.self) {
                // プレーンテキストをペーストした場合
                item.itemProvider.loadObject(ofClass: String.self) { (object, error) in
                    if let str = object as? String {
                        let mutable = NSMutableAttributedString(string: str)
                        let linkedAttr = NSMutableAttributedString.withLinkDetection(from: mutable)
                        
                        linkedAttr.addAttribute(.font, value: font, range: NSRange(location: 0, length: linkedAttr.length))
                        linkedAttr.addAttribute(.foregroundColor, value: normalColor, range: NSRange(location: 0, length: linkedAttr.length))
                        
                        linkedAttr.enumerateAttribute(.link, in: NSRange(location: 0, length: linkedAttr.length)) { value, range, _ in
                            if value != nil {
                                linkedAttr.addAttribute(.foregroundColor, value: linkColor, range: range)
                            }
                        }
                        
                        DispatchQueue.main.async {
                            item.setResult(attributedString: linkedAttr)
                        }
                    }
                }
            }
        }
    
    /// Note から NSMutableAttributedString を復元して UITextView にセット
    private func loadContent() {
        let linkColor = UIColor.systemBlue
        let font = UIFont.systemFont(ofSize: 20)

        let applyAttributes: (NSMutableAttributedString) -> NSMutableAttributedString = { attr in
            // フォント
            attr.addAttribute(.font, value: font, range: NSRange(location: 0, length: attr.length))
            
            // 全体文字色
            attr.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: attr.length))

            // 既存リンクをリンク色に
            attr.enumerateAttribute(.link, in: NSRange(location: 0, length: attr.length)) { value, range, _ in
                if value != nil {
                    attr.addAttribute(.foregroundColor, value: linkColor, range: range)
                }
            }

            // データ検出でリンクが無い部分にリンクを設定
            if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                let matches = detector.matches(in: attr.string, options: [], range: NSRange(location: 0, length: attr.length))
                for match in matches {
                    if let url = match.url {
                        let currentAttr = attr.attribute(.link, at: match.range.location, effectiveRange: nil)
                        if currentAttr == nil {
                            attr.addAttribute(.link, value: url, range: match.range)
                            attr.addAttribute(.foregroundColor, value: linkColor, range: match.range)
                        }
                    }
                }
            }

            return attr
        }

        if let data = note?.mutable,
           let attr = try? NSAttributedString(data: data,
                                              options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                              documentAttributes: nil) {
            let mutableAttr = NSMutableAttributedString(attributedString: attr)

            // フォントやリンクを整える
            let applied = applyAttributes(mutableAttr)

            // 画像サイズを調整
            resizeImagesIn(applied)

            textView.attributedText = applied
        }


        if note == nil {
            let newNote = Note(context: context)
            newNote.id = UUID()
            newNote.makeDate = Date()
            self.note = newNote
            textView.becomeFirstResponder()
        }
    }

    @objc private func saveTapped() {
        saveNote()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        textView.resignFirstResponder()
        
        // ナビゲーションで戻るときだけ保存
        if self.isMovingFromParent {
            saveNote()
        }
        
        //view.endEditing(true)   // ← これでキーボードを閉じる
        
    }
    
    private func saveNote() {
        guard let note = note else { return }

        let textToSave = textView.text ?? ""

        if textToSave.isEmpty {
            if context.registeredObjects.contains(note) {
                context.delete(note)
            }
        } else {
            note.text = textToSave

            // attributedText を RTFD で保存（画像もリンクも残す）
            if let attrText = textView.attributedText {
                note.mutable = try? attrText.data(
                    from: NSRange(location: 0, length: attrText.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
                )
            }
        }

        do {
            try context.save()
            // 保存成功時の処理（トーストなど）
        } catch {
            let nsError = error as NSError
            var message = "保存できませんでした: \(nsError.localizedDescription)"
            if nsError.code == NSFileWriteOutOfSpaceError {
                message = "ストレージ不足で保存できませんでした。"
            }
            Toast.showToast(message: message)
        }
    }

}


// MARK: - NSMutableAttributedString Extension
extension NSMutableAttributedString {
    static func withLinkDetection(from attributedString: NSMutableAttributedString) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(attributedString: attributedString)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return result
        }

        let textRange = NSRange(location: 0, length: result.string.utf16.count)
        detector.enumerateMatches(in: result.string, options: [], range: textRange) { match, _, _ in
            guard let match = match, let url = match.url else { return }
            result.addAttribute(.link, value: url, range: match.range)
        }
        return result
    }
}



// MARK: - NotesTableViewController
class NotesTableViewController: UITableViewController {

    var context: NSManagedObjectContext!
    var notes: [Note] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchNotes()
        title = "Notes"

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addNoteTapped))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchNotes() // 保存後に更新
    }

    // MARK: - TableView DataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ??
            UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        cell.textLabel?.text = notes[indexPath.row].text
        return cell
    }

    // MARK: - TableView Delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        openEditVC(for: notes[indexPath.row])
    }

    // MARK: - 削除
    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let noteToDelete = notes[indexPath.row]
            context.delete(noteToDelete)
            do {
                try context.save()
                notes.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            } catch {
                print("Failed to delete note: \(error)")
            }
        }
    }

    // MARK: - 新規作成
    @objc func addNoteTapped() {
        
        openEditVC(for: nil)
        
        //print("Failed to save new note: \(error)")
    }

    // MARK: - Fetch Notes
    func fetchNotes() {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "makeDate", ascending: false)]
        notes = (try? context.fetch(request)) ?? []
        tableView.reloadData()
    }

    // MARK: - Helpers
    func openEditVC(for note: Note?) {
        let editVC = EditViewController()
        editVC.context = context
        editVC.note = note
        navigationController?.pushViewController(editVC, animated: true)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}





// MARK: - SwiftUI Wrapper
struct ContentView: UIViewControllerRepresentable {
    @Environment(\.managedObjectContext) private var viewContext

    func makeUIViewController(context: Context) -> UINavigationController {
        let notesVC = NotesTableViewController()
        notesVC.context = viewContext
        let nav = UINavigationController(rootViewController: notesVC)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // 更新処理不要
    }
}
