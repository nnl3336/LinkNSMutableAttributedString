//
//  LinkNSMutableAttributedStringApp.swift
//  LinkNSMutableAttributedString
//
//  Created by Yuki Sasaki on 2025/09/06.
//

import SwiftUI

@main
struct LinkNSMutableAttributedStringApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
