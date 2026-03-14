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
    
    /// App Group identifier - должен совпадать в Share Extension
    private let appGroupID = "group.com.share.LinkShareApp"
    private let sharedURLKey = "SharedYouTubeURL"
    private let sharedTimestampKey = "SharedURLTimestamp"
    
    var body: some Scene {
        WindowGroup {
            ContentView(sharedURL: $sharedURL)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    // Проверяем App Group при запуске
                    checkAppGroupForSharedURL()
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Приложение открыто через URL Scheme - читаем URL из App Group
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "share" else {
            return
        }
        
        // Читаем URL из shared UserDefaults
        checkAppGroupForSharedURL()
    }
    
    private func checkAppGroupForSharedURL() {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        // Получаем сохраненный URL
        guard let urlString = userDefaults.string(forKey: sharedURLKey),
              let youtubeURL = URL(string: urlString) else {
            return
        }
        
        // Проверяем timestamp - URL не должен быть старше 60 секунд
        let timestamp = userDefaults.double(forKey: sharedTimestampKey)
        let now = Date().timeIntervalSince1970
        
        if now - timestamp < 60 {
            // URL свежий - используем его
            sharedURL = youtubeURL
            
            // Очищаем после использования
            userDefaults.removeObject(forKey: sharedURLKey)
            userDefaults.removeObject(forKey: sharedTimestampKey)
            userDefaults.synchronize()
        }
    }
}
