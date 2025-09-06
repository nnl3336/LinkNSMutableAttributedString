//
//  ContentView.swift
//  LinkNSMutableAttributedString
//
//  Created by Yuki Sasaki on 2025/09/06.
//

import SwiftUI
import CoreData
import UIKit



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

// MARK: - EditViewController
class EditViewController: UIViewController, UITextViewDelegate {
    
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
        
        restoreContent() // <- 復元用メソッドを呼ぶ
    }
    
    /// Note から NSMutableAttributedString を復元して UITextView にセット
    func restoreContent() {
        guard let note = note else {
            textView.text = ""
            return
        }
        
        if let data = note.content {
            do {
                let attr = try NSAttributedString(data: data,
                                                  options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                                  documentAttributes: nil)
                textView.attributedText = NSMutableAttributedString(attributedString: attr)
            } catch {
                print("Failed to unarchive attributed string: \(error)")
                textView.text = note.text ?? ""
            }
        } else {
            textView.text = note.text ?? ""
        }
    }
    
    @objc private func saveTapped() {
        guard let note = note else { return }
        
        let textToSave = textView.text ?? ""
        
        if textToSave.isEmpty {
            context.delete(note)
        } else {
            note.text = textToSave
            
            let mutableAttr = NSMutableAttributedString(string: textToSave)
            let linkedAttr = NSMutableAttributedString.withLinkDetection(from: mutableAttr)
            
            do {
                note.content = try linkedAttr.data(
                    from: NSRange(location: 0, length: linkedAttr.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
                )
            } catch {
                print("Failed to convert attributed string to RTFD: \(error)")
            }
            
            if note.makeDate == nil {
                note.makeDate = Date()
            }
        }
        
        do {
            try context.save()
            navigationController?.popViewController(animated: true)
        } catch {
            print("Failed to save note: \(error)")
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
        let editVC = EditViewController()
        editVC.context = context
        editVC.note = notes[indexPath.row]
        navigationController?.pushViewController(editVC, animated: true)
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
        let newNote = Note(context: context)
        newNote.text = "新しいノート"
        newNote.makeDate = Date()

        do {
            try context.save()
            notes.append(newNote)
            tableView.reloadData()

            let editVC = EditViewController()
            editVC.context = context
            editVC.note = newNote
            navigationController?.pushViewController(editVC, animated: true)
        } catch {
            print("Failed to save new note: \(error)")
        }
    }

    // MARK: - Fetch Notes
    func fetchNotes() {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "makeDate", ascending: false)]
        notes = (try? context.fetch(request)) ?? []
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}
