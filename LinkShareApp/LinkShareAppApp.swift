//
//  LinkShareAppApp.swift
//  LinkShareApp
//
//  Created by ian on 14.03.2026.
//

import SwiftUI

@main
struct LinkShareAppApp: App {
    @State private var sharedURL: URL?
    
    var body: some Scene {
        WindowGroup {
            ContentView(sharedURL: $sharedURL)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Парсим URL Scheme: linkshareapp://share?url=...
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "share",
              let queryItems = components.queryItems,
              let urlParam = queryItems.first(where: { $0.name == "url" })?.value,
              let decodedURLString = urlParam.removingPercentEncoding,
              let youtubeURL = URL(string: decodedURLString) else {
            return
        }
        
        sharedURL = youtubeURL
    }
}
