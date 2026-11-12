import SwiftUI

@main
struct StarStoreApp: App {
    @StateObject private var manager = RepoManager()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(manager)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var manager: RepoManager
    @State private var searchText = ""
    
    var body: some View {
        TabView {
            TodayTabView()
                .tabItem { Label("Hoy", systemImage: "doc.text.image") }
            GamesTabView()
                .tabItem { Label("Juegos", systemImage: "rocket.fill") }
            AppsTabView()
                .tabItem { Label("Apps", systemImage: "square.stack.3d.up.fill") }
            ReposTabView()
                .tabItem { Label("Repos", systemImage: "shippingbox.fill") }
            SearchTabView(searchText: $searchText)
                .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
        }
    }
}

struct TodayTabView: View {
    @EnvironmentObject var manager: RepoManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if manager.allApps.isEmpty {
                        EmptyReposBanner()
                    } else {
                        HeroCarouselView(apps: manager.featuredToday) { app in manager.getApp(app) }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pruébalo ahora")
                                .font(.title2).fontWeight(.bold).padding(.horizontal, 18)
                            ForEach(manager.allApps.prefix(12)) { app in
                                NavigationLink(value: app) {
                                    AppRowView(app: app) { manager.getApp(app) }.padding(.horizontal, 18)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(.vertical)
            }
            .navigationTitle("Hoy")
            .navigationDestination(for: StoreApp.self) { app in AppDetailView(app: app) { manager.getApp(app) } }
            .refreshable { await manager.refreshAllRepos() }
        }
    }
}

struct GamesTabView: View {
    @EnvironmentObject var manager: RepoManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if manager.allGames.isEmpty {
                        EmptyReposBanner(customText: "Agrega un repositorio con juegos en la pestaña Repos.")
                    } else {
                        HeroCarouselView(apps: manager.featuredGames) { app in manager.getApp(app) }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Juegos que no te puedes perder")
                                .font(.title2).fontWeight(.bold).padding(.horizontal, 18)
                            ForEach(manager.allGames) { game in
                                NavigationLink(value: game) {
                                    AppRowView(app: game) { manager.getApp(game) }.padding(.horizontal, 18)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(.vertical)
            }
            .navigationTitle("Juegos")
            .navigationDestination(for: StoreApp.self) { app in AppDetailView(app: app) { manager.getApp(app) } }
            .refreshable { await manager.refreshAllRepos() }
        }
    }
}

struct AppsTabView: View {
    @EnvironmentObject var manager: RepoManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if manager.nonGameApps.isEmpty {
                        EmptyReposBanner(customText: "Agrega un repositorio en la pestaña Repos para ver aplicaciones.")
                    } else {
                        HeroCarouselView(apps: manager.featuredApps) { app in manager.getApp(app) }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Apps destacadas")
                                .font(.title2).fontWeight(.bold).padding(.horizontal, 18)
                            ForEach(manager.nonGameApps) { app in
                                NavigationLink(value: app) {
                                    AppRowView(app: app) { manager.getApp(app) }.padding(.horizontal, 18)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(.vertical)
            }
            .navigationTitle("Apps")
            .navigationDestination(for: StoreApp.self) { app in AppDetailView(app: app) { manager.getApp(app) } }
            .refreshable { await manager.refreshAllRepos() }
        }
    }
}
struct ReposTabView: View {
    @EnvironmentObject var manager: RepoManager
    @State private var newRepoURL = ""
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                if let error = manager.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.subheadline) }
                }
                Section("Repositorios Activos (\(manager.repositories.count))") {
                    if manager.savedURLs.isEmpty {
                        Text("No has agregado ningún repositorio todavía. Toca el botón + arriba a la derecha para pegar un enlace JSON.")
                            .foregroundStyle(.secondary).font(.subheadline)
                    } else {
                        ForEach(manager.savedURLs, id: \.self) { urlStr in
                            let matchedRepo = manager.repositories.first(where: { $0.sourceURL == urlStr })
                            VStack(alignment: .leading, spacing: 4) {
                                Text(matchedRepo?.name ?? "Cargando repositorio...").font(.headline)
                                Text(urlStr).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                if let count = matchedRepo?.apps.count {
                                    Text("\(count) aplicaciones disponibles").font(.caption2).foregroundStyle(.blue)
                                }
                            }.padding(.vertical, 4)
                        }
                        .onDelete(perform: manager.removeRepo)
                    }
                }
            }
            .navigationTitle("Repos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddSheet = true } label: { Image(systemName: "plus").fontWeight(.semibold) }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NavigationStack {
                    Form {
                        Section("URL del Repositorio JSON") {
                            TextField("https://ejemplo.com", text: $newRepoURL)
                                .keyboardType(.URL).autocapitalization(.none).disableAutocorrection(true)
                        }
                    }
                    .navigationTitle("Agregar Repo").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showingAddSheet = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Agregar") {
                                let urlToAdd = newRepoURL
                                newRepoURL = ""
                                showingAddSheet = false
                                Task { await manager.addRepo(urlString: urlToAdd) }
                            }
                            .disabled(newRepoURL.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }.presentationDetents([.medium])
            }
            .refreshable { await manager.refreshAllRepos() }
        }
    }
}

struct SearchTabView: View {
    @EnvironmentObject var manager: RepoManager
    @Binding var searchText: String
    
    var filteredApps: [StoreApp] {
        if searchText.isEmpty { return manager.allApps }
        return manager.allApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.displaySubtitle.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredApps) { app in
                    NavigationLink(value: app) {
                        AppRowView(app: app) { manager.getApp(app) }
                    }.buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Buscar")
            .searchable(text: $searchText, prompt: "Juegos, apps y más")
            .navigationDestination(for: StoreApp.self) { app in AppDetailView(app: app) { manager.getApp(app) } }
        }
    }
}

struct AppDetailView: View {
    let app: StoreApp
    var onGetTapped: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    AsyncImage(url: app.safeIconURL) { phase in
                        if case .success(let image) = phase { image.resizable().scaledToFill() }
                        else { RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(.systemGray5)) }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(app.name).font(.title2).fontWeight(.bold)
                        Text(app.displaySubtitle).font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        HStack {
                            Button(action: onGetTapped) {
                                Text("Obtener").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                                    .padding(.horizontal, 24).padding(.vertical, 8).background(.blue, in: Capsule())
                            }
                            if let ver = app.version {
                                Text("v\(ver)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }.padding(.horizontal)
                
                if let shots = app.screenshotURLs, !shots.isEmpty {
                    Divider().padding(.horizontal)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vista previa").font(.headline).padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(shots, id: \.self) { str in
                                    if let url = URL(string: str) {
                                        AsyncImage(url: url) { phase in
                                            if case .success(let img) = phase {
                                                img.resizable().scaledToFit().frame(height: 320)
                                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                            }
                                        }
                                    }
                                }
                            }.padding(.horizontal)
                        }
                    }
                }
                
                if let desc = app.localizedDescription, !desc.isEmpty {
                    Divider().padding(.horizontal)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Descripción").font(.headline)
                        Text(desc).font(.body).foregroundStyle(.secondary)
                    }.padding(.horizontal)
                }
            }.padding(.vertical)
        }.navigationBarTitleDisplayMode(.inline)
    }
}

struct EmptyReposBanner: View {
    var customText: String = "Ve a la pestaña Repos abajo y agrega tu primer enlace JSON para llenar la tienda."
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("Tu tienda está vacía").font(.headline)
            Text(customText).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 18)
    }
}

