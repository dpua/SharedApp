//
//  ContentView.swift
//  LinkShareApp
//
//  Created by ian on 14.03.2026.
//

import SwiftUI

struct ContentView: View {
    @Binding var sharedURL: URL?
    @State private var urlHistory: [URL] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Текущая полученная ссылка
                if let url = sharedURL {
                    SharedLinkCard(url: url)
                        .padding()
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    EmptyStateView()
                        .padding()
                }
                
                Divider()
                
                // История ссылок
                if !urlHistory.isEmpty {
                    List {
                        Section("История") {
                            ForEach(urlHistory, id: \.absoluteString) { url in
                                HistoryRow(url: url)
                            }
                            .onDelete(perform: deleteFromHistory)
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    Spacer()
                }
            }
            .navigationTitle("LinkShare")
            .toolbar {
                if !urlHistory.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Очистить") {
                            withAnimation {
                                urlHistory.removeAll()
                            }
                        }
                    }
                }
            }
            .onChange(of: sharedURL) { oldValue, newValue in
                if let url = newValue, !urlHistory.contains(url) {
                    withAnimation {
                        urlHistory.insert(url, at: 0)
                    }
                }
            }
        }
    }
    
    private func deleteFromHistory(at offsets: IndexSet) {
        urlHistory.remove(atOffsets: offsets)
    }
}

// MARK: - Shared Link Card

struct SharedLinkCard: View {
    let url: URL
    @State private var isCopied = false
    
    var body: some View {
        VStack(spacing: 16) {
            // YouTube иконка
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("Получена ссылка YouTube")
                .font(.headline)
            
            // URL
            Text(url.absoluteString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Кнопки действий
            HStack(spacing: 12) {
                Button {
                    openURL(url)
                } label: {
                    Label("Открыть", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    copyToClipboard()
                } label: {
                    Label(isCopied ? "Скопировано" : "Копировать", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = url.absoluteString
        withAnimation {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Нет общих ссылок")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Поделитесь ссылкой YouTube из Safari или приложения YouTube, чтобы она появилась здесь")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let url: URL
    
    var body: some View {
        HStack {
            Image(systemName: "play.rectangle.fill")
                .foregroundStyle(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(videoID ?? "YouTube Video")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                UIApplication.shared.open(url)
            } label: {
                Image(systemName: "arrow.up.right.circle")
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.open(url)
        }
    }
    
    private var videoID: String? {
        // Извлекаем video ID из YouTube URL
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // youtube.com/watch?v=VIDEO_ID
            if let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value {
                return videoID
            }
            // youtu.be/VIDEO_ID
            if url.host == "youtu.be" {
                return url.pathComponents.last
            }
            // youtube.com/shorts/VIDEO_ID
            if url.pathComponents.contains("shorts"), let idx = url.pathComponents.firstIndex(of: "shorts"), idx + 1 < url.pathComponents.count {
                return url.pathComponents[idx + 1]
            }
        }
        return nil
    }
}

#Preview {
    ContentView(sharedURL: .constant(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")))
}
