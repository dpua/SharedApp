//
//  ShareViewController.swift
//  Shared
//
//  Created by ian on 14.03.2026.
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Скрываем view, так как UI не нужен
        view.isHidden = true
        view.alpha = 0
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
        
        Task {
            await processInputItems(inputItems)
        }
    }
    
    private func processInputItems(_ inputItems: [NSExtensionItem]) async {
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            
            for provider in attachments {
                // Проверяем URL
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                        if isYouTubeURL(url) {
                            openMainApp(with: url)
                            return
                        }
                    }
                }
                
                // Проверяем текст (иногда ссылки приходят как текст)
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String,
                       let url = extractYouTubeURL(from: text) {
                        openMainApp(with: url)
                        return
                    }
                }
            }
        }
        
        // Если YouTube ссылка не найдена
        completeRequest()
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
        // Кодируем YouTube URL для передачи через URL Scheme
        guard let encodedURL = youtubeURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completeRequest()
            return
        }
        
        // Формируем URL Scheme для открытия основного приложения
        let urlScheme = "linkshareapp://share?url=\(encodedURL)"
        
        guard let appURL = URL(string: urlScheme) else {
            completeRequest()
            return
        }
        
        // Открываем основное приложение
        openURL(appURL)
    }
    
    // MARK: - Open URL (для iOS 17+)
    
    @discardableResult
    private func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                completeRequest()
                return true
            }
            responder = responder?.next
        }
        
        // Альтернативный способ через selector
        let selector = sel_registerName("openURL:")
        responder = self
        
        while responder != nil {
            if responder!.responds(to: selector) {
                responder!.perform(selector, with: url)
                completeRequest()
                return true
            }
            responder = responder?.next
        }
        
        completeRequest()
        return false
    }
    
    // MARK: - Complete Request
    
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
