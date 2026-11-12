import Foundation
import SwiftUI

// MARK: - Modelos de Datos JSON
struct RepoSource: Codable, Identifiable {
    var id: String { sourceURL ?? name }
    let name: String
    let identifier: String?
    let iconURL: String?
    let apps: [StoreApp]
    var sourceURL: String?
}

struct StoreApp: Codable, Identifiable, Hashable {
    var id: String { "\(bundleIdentifier)-\(version ?? "1.0")" }
    let name: String
    let bundleIdentifier: String
    let developerName: String?
    let subtitle: String?
    let localizedDescription: String?
    let iconURL: String?
    let category: String?
    let screenshotURLs: [String]?
    let versions: [AppVersion]?
    
    var latestVersion: AppVersion? { versions?.first }
    var version: String? { latestVersion?.version }
    var downloadURL: String? { latestVersion?.downloadURL }
    
    var heroImageURL: URL? {
        if let first = screenshotURLs?.first, let url = URL(string: first) { return url }
        return nil
    }
    
    var safeIconURL: URL? {
        guard let iconURL, let url = URL(string: iconURL) else { return nil }
        return url
    }
    
    var displaySubtitle: String {
        if let subtitle, !subtitle.isEmpty { return subtitle }
        if let developerName, !developerName.isEmpty { return developerName }
        return "Repositorio externo"
    }
    
    var isGame: Bool {
        let text = "\(category ?? "") \(localizedDescription ?? "") \(subtitle ?? "")".lowercased()
        return text.contains("game") || text.contains("juego") || text.contains("arcade")
    }
}

struct AppVersion: Codable, Hashable {
    let version: String
    let date: String?
    let localizedDescription: String?
    let downloadURL: String?
    let size: Int?
}

// MARK: - Motor de Repositorios
@MainActor
class RepoManager: ObservableObject {
    @Published var savedURLs: [String] = []
    @Published var repositories: [RepoSource] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    @Published var featuredToday: [StoreApp] = []
    @Published var featuredGames: [StoreApp] = []
    @Published var featuredApps: [StoreApp] = []
    
    private let storageKey = "StarStore_SavedRepoURLs"
    
    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: storageKey) {
            savedURLs = saved
        }
        Task { await refreshAllRepos() }
    }
    
    var allApps: [StoreApp] { repositories.flatMap { $0.apps } }
    var allGames: [StoreApp] { allApps.filter { $0.isGame } }
    var nonGameApps: [StoreApp] { allApps.filter { !$0.isGame } }
    
    func addRepo(urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, URL(string: trimmed) != nil else {
            errorMessage = "El enlace del repositorio no es válido."
            return
        }
        if savedURLs.contains(trimmed) {
            errorMessage = "Este repositorio ya está agregado."
            return
        }
        savedURLs.append(trimmed)
        UserDefaults.standard.set(savedURLs, forKey: storageKey)
        await refreshAllRepos()
    }
    
    func removeRepo(at offsets: IndexSet) {
        savedURLs.remove(atOffsets: offsets)
        UserDefaults.standard.set(savedURLs, forKey: storageKey)
        Task { await refreshAllRepos() }
    }
    
    func refreshAllRepos() async {
        isLoading = true
        errorMessage = nil
        var loaded: [RepoSource] = []
        
        for urlStr in savedURLs {
            guard let url = URL(string: urlStr) else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                var decoded = try JSONDecoder().decode(RepoSource.self, from: data)
                decoded.sourceURL = urlStr
                loaded.append(decoded)
            } catch {
                errorMessage = "No se pudo leer uno de los repositorios."
            }
        }
        
        self.repositories = loaded
        generateRandomHeaders()
        isLoading = false
    }
    
    func generateRandomHeaders() {
        featuredToday = Array(allApps.shuffled().prefix(8))
        featuredGames = Array(allGames.shuffled().prefix(8))
        featuredApps = Array(nonGameApps.shuffled().prefix(8))
    }
    
    func getApp(_ app: StoreApp) {
        guard let str = app.downloadURL, let url = URL(string: str) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Carrusel Horizontal de 8 Tarjetas Hero
struct HeroCarouselView: View {
    let apps: [StoreApp]
    var onGetTapped: (StoreApp) -> Void
    
    var body: some View {
        if !apps.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(apps) { app in
                        NavigationLink(value: app) {
                            HeroAppCard(app: app) {
                                onGetTapped(app)
                            }
                        }
                        .buttonStyle(.plain)
                        .containerRelativeFrame(.horizontal) { length, _ in
                            max(length - 36, 280)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 18, for: .scrollContent)
        }
    }
}

struct HeroAppCard: View {
    let app: StoreApp
    var onGetTapped: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let heroURL = app.heroImageURL {
                    AsyncImage(url: heroURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            fallbackBlurBackground
                        }
                    }
                } else {
                    fallbackBlurBackground
                }
            }
            .frame(height: 230)
            .clipped()
            
            LinearGradient(
                colors: [.clear, .black.opacity(0.25), .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            HStack(alignment: .center, spacing: 12) {
                AsyncImage(url: app.safeIconURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(Image(systemName: "star.fill").foregroundStyle(.white))
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 0.5)
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(app.displaySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                Button(action: onGetTapped) {
                    Text("Obtener")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.35), lineWidth: 0.6)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 5)
    }
    
    private var fallbackBlurBackground: some View {
        ZStack {
            Color(.systemGray5)
            if let iconURL = app.safeIconURL {
                AsyncImage(url: iconURL) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill().blur(radius: 35).scaleEffect(1.2)
                    }
                }
            }
        }
    }
}

// MARK: - Fila Estándar de Lista
struct AppRowView: View {
    let app: StoreApp
    var onGetTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: app.safeIconURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray5))
                        .overlay(Image(systemName: "app.fill").foregroundStyle(.secondary))
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          overlay(
RoundedRectangle(cornerRadius: 14, style: .continuous)
.stroke(.primary.opacity(0.08), lineWidth: 0.5)
)
VStack(alignment: .leading, spacing: 3) {
Text(app.name)
.font(.body)
.fontWeight(.semibold)
.foregroundStyle(.primary)
.lineLimit(1)
Text(app.displaySubtitle)
.font(.subheadline)
.foregroundStyle(.secondary)
.lineLimit(1)
}
Spacer(minLength: 8)
Button(action: onGetTapped) {
Text("Obtener")
.font(.subheadline)
.fontWeight(.bold)
.foregroundStyle(.blue)
.padding(.horizontal, 18)
.padding(.vertical, 7)
.background(Color(.systemGray6), in: Capsule())
}
.buttonStyle(.plain)
}
.padding(.vertical, 4)
}
}
