import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Modèles

/// Fiche d'un saint ou d'une fête issue de Wikipédia : biographie et icône.
public struct SaintProfile: Codable, Hashable, Sendable {
    public let title: String
    public let extract: String
    public let imageURL: URL?
    public let pageURL: URL?
    /// "fr" ou "en".
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

public actor WikipediaService {
    public static let shared = WikipediaService()

    private var memory: [String: SaintProfile?] = [:]

    /// Fiche d'une commémoration : recherche sur Wikipédia en français, puis en anglais.
    public func profile(for c: Commemoration) async -> SaintProfile? {
        let key = "c:" + c.en
        if let cached = cachedProfile(key) { return cached }
        var result = await search(query: c.searchQuery + " saint", language: "fr", mustMatch: c.searchQuery)
        if result == nil || result?.imageURL == nil {
            let english = Self.englishQuery(c.en)
            if let en = await search(query: english + " saint", language: "en", mustMatch: english) {
                if result == nil {
                    result = en
                } else if let fr = result {
                    // Garder le texte français mais emprunter l'icône anglaise.
                    result = SaintProfile(title: fr.title, extract: fr.extract, imageURL: en.imageURL, pageURL: fr.pageURL, language: "fr")
                }
            }
        }
        store(key, result)
        return result
    }

    /// Fiche d'un article connu (fêtes) en français.
    public func profile(forTitle title: String) async -> SaintProfile? {
        let key = "t:" + title
        if let cached = cachedProfile(key) { return cached }
        var comps = URLComponents(string: "https://fr.wikipedia.org/w/api.php")!
        comps.queryItems = Self.commonItems + [
            URLQueryItem(name: "titles", value: title),
            URLQueryItem(name: "redirects", value: "1"),
        ]
        var result: SaintProfile?
        if let url = comps.url, let data = try? await Net.get(url) {
            result = Self.parse(data, language: "fr", mustMatch: nil).first
        }
        store(key, result)
        return result
    }

    // MARK: Implémentation

    private static let commonItems: [URLQueryItem] = [
        URLQueryItem(name: "action", value: "query"),
        URLQueryItem(name: "format", value: "json"),
        URLQueryItem(name: "formatversion", value: "2"),
        URLQueryItem(name: "prop", value: "pageimages|extracts|info"),
        URLQueryItem(name: "piprop", value: "thumbnail"),
        URLQueryItem(name: "pithumbsize", value: "640"),
        URLQueryItem(name: "exintro", value: "1"),
        URLQueryItem(name: "explaintext", value: "1"),
        URLQueryItem(name: "exlimit", value: "max"),
        URLQueryItem(name: "inprop", value: "url"),
    ]

    private func search(query: String, language: String, mustMatch: String) async -> SaintProfile? {
        var comps = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")!
        comps.queryItems = Self.commonItems + [
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: query),
            URLQueryItem(name: "gsrlimit", value: "4"),
            URLQueryItem(name: "redirects", value: "1"),
        ]
        guard let url = comps.url, let data = try? await Net.get(url) else { return nil }
        let candidates = Self.parse(data, language: language, mustMatch: mustMatch)
        return candidates.first(where: { $0.imageURL != nil }) ?? candidates.first
    }

    static func englishQuery(_ en: String) -> String {
        var s = en
        if let r = s.range(of: ",") { s = String(s[..<r.lowerBound]) }
        for p in ["The Holy ", "Holy ", "Saint ", "St. ", "Our Righteous Father ", "Righteous ", "Our Holy Father "] {
            if s.hasPrefix(p) { s = String(s.dropFirst(p.count)) }
        }
        return s
    }

    /// Normalise pour comparer sans accents ni casse.
    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    static let stopWords: Set<String> = ["saint", "sainte", "saints", "saintes", "martyr", "martyre", "martyrs",
                                         "the", "and", "les", "des", "de", "du", "la", "le", "et", "of", "apotre",
                                         "eveque", "pere", "holy", "juste", "grand", "grande"]

    static func parse(_ data: Data, language: String, mustMatch: String?) -> [SaintProfile] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = root["query"] as? [String: Any],
              let pages = query["pages"] as? [[String: Any]] else { return [] }
        let sorted = pages.sorted { ($0["index"] as? Int ?? 0) < ($1["index"] as? Int ?? 0) }
        let tokens: [String] = mustMatch.map { m in
            fold(m).components(separatedBy: CharacterSet.letters.inverted)
                .filter { $0.count > 3 && !stopWords.contains($0) }
        } ?? []
        var out: [SaintProfile] = []
        for page in sorted {
            guard let title = page["title"] as? String else { continue }
            if page["missing"] != nil { continue }
            let extract = (page["extract"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !tokens.isEmpty {
                let t = fold(title)
                // Le titre de l'article doit contenir au moins un mot significatif de la requête.
                guard tokens.contains(where: { t.contains($0) }) else { continue }
            }
            // Écarter les pages d'homonymie.
            if extract.isEmpty || fold(extract).contains("peut designer") || extract.contains("may refer to") { continue }
            var image: URL?
            if let thumb = page["thumbnail"] as? [String: Any], let src = thumb["source"] as? String {
                image = URL(string: src)
            }
            let pageURL = (page["fullurl"] as? String).flatMap(URL.init(string:))
            out.append(SaintProfile(title: title, extract: extract, imageURL: image, pageURL: pageURL, language: language))
        }
        return out
    }

    // MARK: Cache

    private func cachedProfile(_ key: String) -> SaintProfile?? {
        if let m = memory[key] { return .some(m) }
        let file = Net.cacheDirectory.appendingPathComponent("wiki-" + Net.fileName(for: key) + ".json")
        if let data = try? Data(contentsOf: file) {
            if data.isEmpty { memory[key] = .some(nil); return .some(nil) }
            if let p = try? JSONDecoder().decode(SaintProfile.self, from: data) {
                memory[key] = p
                return .some(p)
            }
        }
        return nil
    }

    private func store(_ key: String, _ profile: SaintProfile?) {
        memory[key] = .some(profile)
        let file = Net.cacheDirectory.appendingPathComponent("wiki-" + Net.fileName(for: key) + ".json")
        // On ne mémorise sur disque que les réussites, pour réessayer plus tard en cas d'échec réseau.
        if let profile, let data = try? JSONEncoder().encode(profile) {
            try? data.write(to: file, options: .atomic)
        }
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
