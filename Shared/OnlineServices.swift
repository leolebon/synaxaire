import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Modèles

/// Fiche d'un saint ou d'une fête issue de Wikipédia : nom, biographie et image principale de l'article.
public struct SaintProfile: Codable, Hashable, Sendable {
    /// Titre de l'article.
    public let title: String
    /// Nom à afficher (titre sans précision entre parenthèses).
    public let name: String
    public let extract: String
    public let imageURL: URL?
    public let pageURL: URL?
    /// Langue de l'article (fr, en, el, ru, ro, ar).
    public let language: String
}

/// Vie d'un saint telle que publiée par orthocal.info (en anglais).
public struct SaintStory: Codable, Hashable, Identifiable, Sendable {
    public let title: String
    public let text: String
    public var id: String { title }
}

enum Net {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.requestCachePolicy = .returnCacheDataElseLoad
        #if canImport(FoundationNetworking)
        config.urlCache = URLCache(memoryCapacity: 8_000_000, diskCapacity: 60_000_000, diskPath: nil)
        #else
        config.urlCache = URLCache(memoryCapacity: 8_000_000, diskCapacity: 60_000_000)
        #endif
        return URLSession(configuration: config)
    }()

    static let userAgent = "Synaxaire/1.0 (application iOS de calendrier orthodoxe; usage personnel)"

    static func get(_ url: URL, timeout: TimeInterval = 15) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        #if canImport(FoundationNetworking)
        let (data, response): (Data, URLResponse?) = try await withCheckedThrowingContinuation { cont in
            session.dataTask(with: request) { d, r, e in
                if let e { cont.resume(throwing: e) } else { cont.resume(returning: (d ?? Data(), r)) }
            }.resume()
        }
        #else
        let (data, response) = try await session.data(for: request)
        #endif
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Synaxaire", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Nom de fichier stable à partir d'une clé quelconque.
    static func fileName(for key: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for b in key.utf8 { hash = (hash ^ UInt64(b)) &* 1099511628211 }
        return String(hash, radix: 16)
    }
}

// MARK: - Wikipédia (biographie + icône)

/// Recherche prudente de l'article Wikipédia d'un saint.
/// Principe : mieux vaut aucune image qu'une image hors sujet.
/// 1. article connu (grandes fêtes, grands saints) ;
/// 2. titre exact construit à partir du nom (fr puis en), page non ambiguë qui parle bien d'un saint ;
/// 3. recherche plein texte, en n'acceptant qu'un titre contenant TOUS les mots du nom.
/// L'image est toujours l'image principale de l'article retenu.
/// Le nom et la biographie sont ensuite pris dans la langue de l'utilisateur grâce aux liens interlangues.
public actor WikipediaService {
    public static let shared = WikipediaService()

    private var memory: [String: SaintProfile?] = [:]

    struct Page {
        let title: String
        let language: String
        let extract: String
        let image: URL?
        let url: URL?
        let links: [String: String]
        let disambiguation: Bool
    }

    public func profile(for c: Commemoration?, knownTitle: String?, language: String) async -> SaintProfile? {
        let key = "v2|\(knownTitle ?? "-")|\(c?.en ?? "-")|\(language)"
        if let cached = cachedProfile(key) { return cached }

        var base: Page?
        if let knownTitle {
            base = await fetch(titles: [knownTitle], language: "fr", requireSaint: false)
        }
        if base == nil, let c {
            base = await resolve(c)
        }
        var result: SaintProfile?
        if let base {
            result = await localize(base, to: language)
        }
        store(key, result)
        return result
    }

    // MARK: Résolution

    private func resolve(_ c: Commemoration) async -> Page? {
        let fr = Self.frenchName(c)
        let en = Self.englishName(c.en)
        if !fr.isEmpty, let p = await fetch(titles: [fr, fr + " (saint)", "Saint " + fr], language: "fr", requireSaint: true) { return p }
        if !en.isEmpty, let p = await fetch(titles: [en, "Saint " + en, en + " (saint)"], language: "en", requireSaint: true) { return p }
        if !fr.isEmpty, let p = await search(fr, language: "fr") { return p }
        if !en.isEmpty, let p = await search(en, language: "en") { return p }
        return nil
    }

    private func localize(_ base: Page, to language: String) async -> SaintProfile {
        if base.language == language { return Self.profile(base, imageFallback: nil) }
        if let title = base.links[language],
           let page = await fetch(titles: [title], language: language, requireSaint: false) {
            return Self.profile(page, imageFallback: base.image)
        }
        // Pas d'article dans la langue demandée : l'anglais est plus largement compris que le français.
        if language != "fr", base.language == "fr", let title = base.links["en"],
           let page = await fetch(titles: [title], language: "en", requireSaint: false) {
            return Self.profile(page, imageFallback: base.image)
        }
        return Self.profile(base, imageFallback: nil)
    }

    static func profile(_ p: Page, imageFallback: URL?) -> SaintProfile {
        SaintProfile(title: p.title, name: cleanTitle(p.title), extract: p.extract,
                     imageURL: p.image ?? imageFallback, pageURL: p.url, language: p.language)
    }

    static func cleanTitle(_ t: String) -> String {
        if let r = t.range(of: " (") { return String(t[..<r.lowerBound]) }
        return t
    }

    // MARK: Noms

    static func frenchName(_ c: Commemoration) -> String {
        let lower = fold(c.fr)
        // Les mémoires d'événements (translations de reliques, synaxes…) n'ont pas d'article propre fiable.
        for event in ["translation", "invention", "synaxe", "dedicace", "memoire", "deposition", "apparition", "veneration", "retour"] where lower.hasPrefix(event) {
            return ""
        }
        return c.searchQuery
    }

    static func englishName(_ en: String) -> String {
        var s = en
        if let r = s.range(of: ",") { s = String(s[..<r.lowerBound]) }
        if let r = s.range(of: " (") { s = String(s[..<r.lowerBound]) }
        let lower = fold(s)
        for event in ["removal", "translation", "finding", "synaxis", "commemoration", "placing", "deposition", "appearance", "veneration", "return", "dedication", "consecration"] where lower.hasPrefix(event) || lower.hasPrefix("the " + event) {
            return ""
        }
        let prefixes = ["The Holy ", "Holy ", "Saints ", "Saint ", "Sts. ", "Sts ", "St. ", "St ", "Our Righteous Father ",
                        "Our Holy Father ", "Righteous ", "Hieromartyr ", "Great Martyr ", "Martyrs ", "Martyr ",
                        "New Martyr ", "Venerable ", "The "]
        var changed = true
        while changed {
            changed = false
            for p in prefixes where s.hasPrefix(p) {
                s = String(s.dropFirst(p.count))
                changed = true
            }
        }
        for suffix in [" the Martyr", " the Righteous", " the Hieromartyr", " the Confessor"] where s.hasSuffix(suffix) {
            s = String(s.dropLast(suffix.count))
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: Requêtes

    private static let commonItems: [URLQueryItem] = [
        URLQueryItem(name: "action", value: "query"),
        URLQueryItem(name: "format", value: "json"),
        URLQueryItem(name: "formatversion", value: "2"),
        URLQueryItem(name: "redirects", value: "1"),
        URLQueryItem(name: "prop", value: "pageimages|extracts|info|pageprops|langlinks"),
        URLQueryItem(name: "piprop", value: "thumbnail"),
        URLQueryItem(name: "pithumbsize", value: "640"),
        URLQueryItem(name: "ppprop", value: "disambiguation"),
        URLQueryItem(name: "exintro", value: "1"),
        URLQueryItem(name: "explaintext", value: "1"),
        URLQueryItem(name: "exlimit", value: "max"),
        URLQueryItem(name: "inprop", value: "url"),
        URLQueryItem(name: "lllimit", value: "max"),
    ]

    /// Récupère la première page existante parmi des titres candidats (dans l'ordre donné).
    private func fetch(titles: [String], language: String, requireSaint: Bool) async -> Page? {
        var comps = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")!
        comps.queryItems = Self.commonItems + [URLQueryItem(name: "titles", value: titles.joined(separator: "|"))]
        guard let url = comps.url, let data = try? await Net.get(url) else { return nil }
        guard let (pages, aliases) = Self.parse(data, language: language) else { return nil }
        for candidate in titles {
            var t = candidate
            for _ in 0..<3 { if let next = aliases[t] { t = next } }
            guard let page = pages.first(where: { $0.title == t }) else { continue }
            if page.disambiguation || page.extract.isEmpty { continue }
            if requireSaint && !Self.looksLikeSaint(page.extract) { continue }
            return page
        }
        return nil
    }

    /// Recherche plein texte stricte : le titre doit contenir tous les mots significatifs du nom.
    private func search(_ name: String, language: String) async -> Page? {
        let tokens = Self.tokens(name)
        guard !tokens.isEmpty else { return nil }
        var comps = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")!
        comps.queryItems = Self.commonItems + [
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: name),
            URLQueryItem(name: "gsrlimit", value: "5"),
        ]
        guard let url = comps.url, let data = try? await Net.get(url) else { return nil }
        guard let (pages, _) = Self.parse(data, language: language) else { return nil }
        for page in pages {
            let title = Self.fold(page.title)
            guard tokens.allSatisfy({ title.contains($0) }) else { continue }
            if page.disambiguation || page.extract.isEmpty || !Self.looksLikeSaint(page.extract) { continue }
            return page
        }
        return nil
    }

    static func parse(_ data: Data, language: String) -> ([Page], [String: String])? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = root["query"] as? [String: Any] else { return nil }
        var aliases: [String: String] = [:]
        for key in ["normalized", "redirects"] {
            for item in (query[key] as? [[String: Any]]) ?? [] {
                if let from = item["from"] as? String, let to = item["to"] as? String { aliases[from] = to }
            }
        }
        let raw = (query["pages"] as? [[String: Any]]) ?? []
        let sorted = raw.sorted { ($0["index"] as? Int ?? 0) < ($1["index"] as? Int ?? 0) }
        let pages: [Page] = sorted.compactMap { p in
            guard let title = p["title"] as? String, p["missing"] == nil, p["invalid"] == nil else { return nil }
            var image: URL?
            if let thumb = p["thumbnail"] as? [String: Any], let src = thumb["source"] as? String { image = URL(string: src) }
            var links: [String: String] = [:]
            for l in (p["langlinks"] as? [[String: Any]]) ?? [] {
                if let lang = l["lang"] as? String, let t = l["title"] as? String { links[lang] = t }
            }
            let props = p["pageprops"] as? [String: Any]
            return Page(title: title,
                        language: language,
                        extract: (p["extract"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                        image: image,
                        url: (p["fullurl"] as? String).flatMap(URL.init(string:)),
                        links: links,
                        disambiguation: props?["disambiguation"] != nil)
        }
        return (pages, aliases)
    }

    // MARK: Outils texte

    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    static let stopWords: Set<String> = ["saint", "sainte", "saints", "saintes", "the", "and", "les", "des", "de", "du",
                                         "la", "le", "et", "of", "with", "his", "her", "their", "avec", "ses", "leur"]

    static func tokens(_ s: String) -> [String] {
        fold(s).components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }
    }

    static let saintWords = ["saint", "martyr", "apotre", "apostle", "prophet", "eveque", "bishop", "moine", "monk",
                             "moniale", "nun", "ermite", "hermit", "patriarch", "ascet", "venere", "venerated",
                             "orthodox", "pape", "pope", "theolog", "thaumaturge", "wonderworker", "diacre", "deacon",
                             "pretre", "priest", "confess", "higoumene", "abbot", "abbess", "abbesse", "stylite",
                             "eglise", "church", "chretien", "christian", "canonis", "fete", "feast", "icone", "icon"]

    static func looksLikeSaint(_ extract: String) -> Bool {
        let f = fold(String(extract.prefix(1200)))
        return saintWords.contains(where: { f.contains($0) })
    }

    // MARK: Cache

    private func cachedProfile(_ key: String) -> SaintProfile?? {
        if let m = memory[key] { return .some(m) }
        let file = Net.cacheDirectory.appendingPathComponent("wiki-" + Net.fileName(for: key) + ".json")
        if let data = try? Data(contentsOf: file), let p = try? JSONDecoder().decode(SaintProfile.self, from: data) {
            memory[key] = p
            return .some(p)
        }
        return nil
    }

    private func store(_ key: String, _ profile: SaintProfile?) {
        memory[key] = .some(profile)
        guard let profile, let data = try? JSONEncoder().encode(profile) else { return }
        let file = Net.cacheDirectory.appendingPathComponent("wiki-" + Net.fileName(for: key) + ".json")
        try? data.write(to: file, options: .atomic)
    }
}

// MARK: - orthocal.info (vies des saints, tradition grecque)

public actor OrthocalService {
    public static let shared = OrthocalService()
    private var memory: [String: [SaintStory]] = [:]

    public func stories(for civil: CivilDate, calendar: ChurchCalendar) async throws -> [SaintStory] {
        let cal = calendar == .newCalendar ? "gregorian" : "julian"
        let key = "\(cal)-\(civil.year)-\(civil.month)-\(civil.day)"
        if let m = memory[key] { return m }
        let file = Net.cacheDirectory.appendingPathComponent("orthocal-" + key + ".json")
        if let data = try? Data(contentsOf: file), let cached = try? JSONDecoder().decode([SaintStory].self, from: data) {
            memory[key] = cached
            return cached
        }
        let url = URL(string: "https://orthocal.info/api/greek/\(cal)/\(civil.year)/\(civil.month)/\(civil.day)/")!
        let data = try await Net.get(url, timeout: 20)
        let stories = Self.parse(data)
        memory[key] = stories
        if let encoded = try? JSONEncoder().encode(stories) { try? encoded.write(to: file, options: .atomic) }
        return stories
    }

    static func parse(_ data: Data) -> [SaintStory] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root["stories"] as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let title = item["title"] as? String, let html = item["story"] as? String else { return nil }
            let text = HTMLText.plain(html)
            return text.isEmpty ? nil : SaintStory(title: title, text: text)
        }
    }
}

// MARK: - Images (avec cache disque)

public enum ImageCache {
    public static func data(for url: URL, timeout: TimeInterval = 15) async -> Data? {
        let file = Net.cacheDirectory.appendingPathComponent("img-" + Net.fileName(for: url.absoluteString))
        if let d = try? Data(contentsOf: file), !d.isEmpty { return d }
        guard let d = try? await Net.get(url, timeout: timeout) else { return nil }
        try? d.write(to: file, options: .atomic)
        return d
    }
}

// MARK: - HTML → texte

public enum HTMLText {
    public static func plain(_ html: String) -> String {
        var s = html
        let breaks = ["<br>", "<br/>", "<br />", "</p>", "</div>", "</li>", "</h1>", "</h2>", "</h3>", "</h4>", "</blockquote>"]
        for b in breaks { s = s.replacingOccurrences(of: b, with: "\n\n", options: .caseInsensitive) }
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities: [String: String] = [
            "&amp;": "&", "&quot;": "\"", "&apos;": "'", "&#39;": "'", "&lt;": "<", "&gt;": ">",
            "&nbsp;": " ", "&rsquo;": "’", "&lsquo;": "‘", "&ldquo;": "“", "&rdquo;": "”",
            "&mdash;": "—", "&ndash;": "–", "&hellip;": "…",
        ]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        // Entités numériques &#1234;
        while let r = s.range(of: "&#[0-9]+;", options: .regularExpression) {
            let num = s[r].dropFirst(2).dropLast()
            let replacement = Int(num).flatMap(UnicodeScalar.init).map { String(Character($0)) } ?? ""
            s.replaceSubrange(r, with: replacement)
        }
        // Espaces superflus.
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n\\s*\\n\\s*(\\n\\s*)+", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Paragraphes non vides (utile pour la traduction paragraphe par paragraphe).
    public static func paragraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
