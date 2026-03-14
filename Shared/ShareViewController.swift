//
//  ShareViewController.swift
//  Shared
//
//  Created by ian on 14.03.2026.
//

import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: UIViewController {
    
    // MARK: - Constants
    
    /// App Group identifier - должен совпадать в основном приложении и extension
    private let appGroupID = "group.com.share.LinkShareApp"
    private let sharedURLKey = "SharedYouTubeURL"
    private let sharedTimestampKey = "SharedURLTimestamp"
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Полностью прозрачный view без UI
        view.backgroundColor = .clear
        view.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSharedContent()
    }
    
    // MARK: - Handle Shared Content
    
    private func handleSharedContent() {
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }
        
        processInputItems(inputItems)
    }
    
    private func processInputItems(_ inputItems: [NSExtensionItem]) {
        let group = DispatchGroup()
        var foundURL: URL?
        
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            
            for provider in attachments {
                // Проверяем URL
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
                        defer { group.leave() }
                        
                        if let url = item as? URL, self?.isYouTubeURL(url) == true {
                            foundURL = url
                        } else if let urlData = item as? Data,
                                  let url = URL(dataRepresentation: urlData, relativeTo: nil),
                                  self?.isYouTubeURL(url) == true {
                            foundURL = url
                        }
                    }
                }
                
                // Проверяем текст (иногда ссылки приходят как текст)
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
                        defer { group.leave() }
                        
                        if let text = item as? String,
                           let url = self?.extractYouTubeURL(from: text) {
                            foundURL = url
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            if let url = foundURL {
                self?.openMainApp(with: url)
            } else {
                self?.completeRequest()
            }
        }
    }
    
    // MARK: - YouTube URL Validation
    
    private func isYouTubeURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        
        let youtubeHosts = [
            "youtube.com",
            "www.youtube.com",
            "m.youtube.com",
            "youtu.be",
            "www.youtu.be"
        ]
        
        return youtubeHosts.contains(host)
    }
    
    private func extractYouTubeURL(from text: String) -> URL? {
        // Паттерн для YouTube ссылок
        let patterns = [
            "https?://(?:www\\.)?youtube\\.com/watch\\?[^\\s]+",
            "https?://(?:www\\.)?youtube\\.com/shorts/[^\\s]+",
            "https?://(?:www\\.)?youtube\\.com/live/[^\\s]+",
            "https?://youtu\\.be/[^\\s]+",
            "https?://(?:m\\.)?youtube\\.com/[^\\s]+"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let urlString = String(text[range])
                if let url = URL(string: urlString) {
                    return url
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Open Main App
    
    private func openMainApp(with youtubeURL: URL) {
        // 1. Сохраняем URL в shared UserDefaults через App Group
        saveURLToAppGroup(youtubeURL)
        
        // 2. Формируем URL Scheme для открытия основного приложения
        // Передаем URL и через URL Scheme, и через App Group (двойная гарантия)
        let urlScheme = "linkshareapp://share"
        
        guard let appURL = URL(string: urlScheme) else {
            completeRequest()
            return
        }
        
        // 3. Открываем основное приложение
        openURL(appURL)
    }
    
    // MARK: - App Group Storage
    
    private func saveURLToAppGroup(_ url: URL) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            return
        }
        
        // Сохраняем URL и timestamp
        userDefaults.set(url.absoluteString, forKey: sharedURLKey)
        userDefaults.set(Date().timeIntervalSince1970, forKey: sharedTimestampKey)
        userDefaults.synchronize()
    }
    
    // MARK: - Open URL (для iOS 17/18+)
    
    @objc @discardableResult
    private func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        
        while responder != nil {
            if let application = responder as? UIApplication {
                // iOS 18+ требует использования open(_:options:completionHandler:)
                application.open(url, options: [:]) { [weak self] success in
                    DispatchQueue.main.async {
                        self?.completeRequest()
                    }
                }
                return true
            }
            responder = responder?.next
        }
        
        // Fallback: если UIApplication не найден, закрываем extension
        completeRequest()
        return false
    }
    
    // MARK: - Complete Request
    
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
