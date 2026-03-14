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
        // В iOS 17+ нужно использовать open(_:options:completionHandler:)
        // Share Extension не имеет доступа к UIApplication.shared напрямую
        // Используем workaround через NSExtensionContext
        
        // Способ 1: Через URL и completeRequest с openURL
        let selectorOpenURL = sel_registerName("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        
        while responder != nil {
            if responder!.responds(to: selectorOpenURL) {
                let implementation = responder!.method(for: selectorOpenURL)
                typealias OpenURLFunction = @convention(c) (AnyObject, Selector, URL, [UIApplication.OpenExternalURLOptionsKey: Any], ((Bool) -> Void)?) -> Void
                let function = unsafeBitCast(implementation, to: OpenURLFunction.self)
                function(responder!, selectorOpenURL, url, [:]) { [weak self] success in
                    DispatchQueue.main.async {
                        self?.completeRequest()
                    }
                }
                return
            }
            responder = responder?.next
        }
        
        // Способ 2: Fallback через NSExtensionContext.open (iOS 17+)
        if #available(iOS 17.0, *) {
            Task {
                do {
                    try await self.extensionContext?.open(url)
                } catch {
                    // Ошибка открытия URL
                }
                await MainActor.run {
                    self.completeRequest()
                }
            }
        } else {
            // Для более старых версий iOS
            completeRequest()
        }
    }
    
    // MARK: - Complete Request
    
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
