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
    
    private func openURL(_ url: URL) {
        // Используем openURL через UIApplication.shared через responder chain
        // Это единственный рабочий способ в Share Extension
        
        var responder: UIResponder? = self as UIResponder
        let selector = NSSelectorFromString("openURL:")
        
        while responder != nil {
            if responder!.responds(to: selector) {
                _ = responder!.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }
        
        // Небольшая задержка перед закрытием extension
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.completeRequest()
        }
    }
    
    // MARK: - Complete Request
    
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
