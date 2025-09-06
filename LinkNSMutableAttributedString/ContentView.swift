//
//  ContentView.swift
//  LinkNSMutableAttributedString
//
//  Created by Yuki Sasaki on 2025/09/06.
//

import SwiftUI
import CoreData

import UIKit

struct ContentView: UIViewControllerRepresentable {
    @Environment(\.managedObjectContext) private var viewContext

    func makeUIViewController(context: Context) -> UINavigationController {
        let notesVC = NotesTableViewController()
        notesVC.context = viewContext
        let nav = UINavigationController(rootViewController: notesVC)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // 特に更新処理は不要
    }
}


class EditViewController: UIViewController, UITextViewDelegate {

    var context: NSManagedObjectContext!
    var note: Note?

    let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        textView.frame = view.bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(textView)

        if let note = note, let data = note.content {
            textView.attributedText = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSMutableAttributedString
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
    }

    @objc func saveTapped() {
        guard let note = note else { return }

        // NSMutableAttributedString を Data に変換
        if let attributedString = textView.attributedText as? NSMutableAttributedString {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: attributedString, requiringSecureCoding: false) {
                note.content = data
            }
        }

        do {
            try context.save()
            navigationController?.popViewController(animated: true)
        } catch {
            print("Failed to save: \(error)")
        }
    }
}


class NotesTableViewController: UITableViewController {

    var context: NSManagedObjectContext!
    var notes: [Note] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchNotes()
        
        // ナビゲーションバーに新規作成ボタン
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addNoteTapped))
    }
    
    // 削除可能にする
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    // 削除アクション
    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Core Data から削除
            let noteToDelete = notes[indexPath.row]
            context.delete(noteToDelete)
            
            do {
                try context.save()
                // 配列と TableView からも削除
                notes.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            } catch {
                print("Failed to delete note: \(error)")
            }
        }
    }


    @objc func addNoteTapped() {
        // 新規 Note を作成
        let newNote = Note(context: context)
        newNote.title = "新しいノート"

        // 保存
        do {
            try context.save()
            notes.append(newNote)
            tableView.reloadData()

            // 直接 EditViewController に遷移して編集可能に
            let editVC = EditViewController()
            editVC.context = context
            editVC.note = newNote
            navigationController?.pushViewController(editVC, animated: true)
        } catch {
            print("Failed to save new note: \(error)")
        }
    }


    func fetchNotes() {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        notes = (try? context.fetch(request)) ?? []
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        notes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        cell.textLabel?.text = notes[indexPath.row].title
        return cell
    }

    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let editVC = EditViewController()
        editVC.context = context
        editVC.note = notes[indexPath.row]
        navigationController?.pushViewController(editVC, animated: true)
    }
}
