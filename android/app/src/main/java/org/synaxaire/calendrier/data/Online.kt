package org.synaxaire.calendrier.data

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.synaxaire.calendrier.engine.ChurchCalendar
import org.synaxaire.calendrier.engine.CivilDate
import org.synaxaire.calendrier.engine.Commemoration
import org.synaxaire.calendrier.engine.Json
import org.synaxaire.calendrier.engine.asList
import org.synaxaire.calendrier.engine.asMap
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.Normalizer

/** Fiche Wikipédia : nom, biographie et image principale de l'article. */
data class SaintProfile(
    val title: String,
    val name: String,
    val extract: String,
    val imageUrl: String?,
    val pageUrl: String?,
    val language: String,
)

/** Vie d'un saint publiée par orthocal.info (en anglais). */
data class SaintStory(val title: String, val text: String)

object Net {
    private const val USER_AGENT = "Synaxaire/2.0 (Android; calendrier orthodoxe, usage personnel)"

    fun enc(s: String): String = URLEncoder.encode(s, "UTF-8")

    suspend fun bytes(url: String, timeoutMs: Int = 15000): ByteArray? = withContext(Dispatchers.IO) {
        try {
            val c = URL(url).openConnection() as HttpURLConnection
            c.connectTimeout = timeoutMs
            c.readTimeout = timeoutMs
            c.setRequestProperty("User-Agent", USER_AGENT)
            try {
                if (c.responseCode !in 200..299) null else c.inputStream.use { it.readBytes() }
            } finally {
                c.disconnect()
            }
        } catch (e: Exception) {
            null
        }
    }

    suspend fun text(url: String, timeoutMs: Int = 15000): String? = bytes(url, timeoutMs)?.toString(Charsets.UTF_8)

    fun cacheFile(prefix: String, key: String): File {
        var h = 1469598103934665603uL
        for (b in key.toByteArray()) h = (h xor b.toUByte().toULong()) * 1099511628211uL
        return File(AppData.cacheDir, prefix + h.toString(16))
    }
}

// ---------------------------------------------------------------------------
// Wikipédia : identification prudente de l'article (mieux vaut pas d'image qu'une image fausse)
// ---------------------------------------------------------------------------

object Wikipedia {
    private val memory = HashMap<String, SaintProfile?>()
    private val mutex = Mutex()

    private class Page(
        val title: String,
        val language: String,
        val extract: String,
        val image: String?,
        val url: String?,
        val links: Map<String, String>,
        val disambiguation: Boolean,
    )

    suspend fun profile(c: Commemoration?, knownTitle: String?, language: String): SaintProfile? {
        val key = "v2|${knownTitle ?: "-"}|${c?.en ?: "-"}|$language"
        mutex.withLock { if (memory.containsKey(key)) return memory[key] }
        val file = Net.cacheFile("wiki-", key)
        readCached(file)?.let { p -> mutex.withLock { memory[key] = p }; return p }

        var base: Page? = null
        if (knownTitle != null) base = fetch(listOf(knownTitle), "fr", requireSaint = false)
        if (base == null && c != null) base = resolve(c)
        val result = base?.let { localize(it, language) }
        mutex.withLock { memory[key] = result }
        if (result != null) writeCached(file, result)
        return result
    }

    private suspend fun resolve(c: Commemoration): Page? {
        val fr = frenchName(c)
        val en = englishName(c.en)
        if (fr.isNotEmpty()) fetch(listOf(fr, "$fr (saint)", "Saint $fr"), "fr", true)?.let { return it }
        if (en.isNotEmpty()) fetch(listOf(en, "Saint $en", "$en (saint)"), "en", true)?.let { return it }
        if (fr.isNotEmpty()) search(fr, "fr")?.let { return it }
        if (en.isNotEmpty()) search(en, "en")?.let { return it }
        return null
    }

    private suspend fun localize(base: Page, language: String): SaintProfile {
        if (base.language == language) return toProfile(base, null)
        base.links[language]?.let { t -> fetch(listOf(t), language, false)?.let { return toProfile(it, base.image) } }
        if (language != "fr" && base.language == "fr") {
            base.links["en"]?.let { t -> fetch(listOf(t), "en", false)?.let { return toProfile(it, base.image) } }
        }
        return toProfile(base, null)
    }

    private fun toProfile(p: Page, imageFallback: String?) =
        SaintProfile(p.title, cleanTitle(p.title), p.extract, p.image ?: imageFallback, p.url, p.language)

    fun cleanTitle(t: String): String = t.substringBefore(" (")

    fun frenchName(c: Commemoration): String {
        val lower = fold(c.fr)
        val events = listOf("translation", "invention", "synaxe", "dedicace", "memoire", "deposition", "apparition", "veneration", "retour")
        if (events.any { lower.startsWith(it) }) return ""
        return c.searchQuery
    }

    fun englishName(en: String): String {
        var s = en.substringBefore(",").substringBefore(" (")
        val lower = fold(s)
        val events = listOf("removal", "translation", "finding", "synaxis", "commemoration", "placing", "deposition",
            "appearance", "veneration", "return", "dedication", "consecration")
        if (events.any { lower.startsWith(it) || lower.startsWith("the $it") }) return ""
        val prefixes = listOf("The Holy ", "Holy ", "Saints ", "Saint ", "Sts. ", "Sts ", "St. ", "St ", "Our Righteous Father ",
            "Our Holy Father ", "Righteous ", "Hieromartyr ", "Great Martyr ", "Martyrs ", "Martyr ", "New Martyr ", "Venerable ", "The ")
        var changed = true
        while (changed) {
            changed = false
            for (p in prefixes) if (s.startsWith(p)) { s = s.substring(p.length); changed = true }
        }
        for (suffix in listOf(" the Martyr", " the Righteous", " the Hieromartyr", " the Confessor")) {
            if (s.endsWith(suffix)) s = s.dropLast(suffix.length)
        }
        return s.trim()
    }

    private const val PROPS = "action=query&format=json&formatversion=2&redirects=1" +
        "&prop=pageimages%7Cextracts%7Cinfo%7Cpageprops%7Clanglinks&piprop=thumbnail&pithumbsize=640" +
        "&ppprop=disambiguation&exintro=1&explaintext=1&exlimit=max&inprop=url&lllimit=max"

    private suspend fun fetch(titles: List<String>, language: String, requireSaint: Boolean): Page? {
        val url = "https://$language.wikipedia.org/w/api.php?$PROPS&titles=" + Net.enc(titles.joinToString("|"))
        val json = Net.text(url) ?: return null
        val (pages, aliases) = parse(json, language) ?: return null
        for (candidate in titles) {
            var t = candidate
            repeat(3) { aliases[t]?.let { t = it } }
            val page = pages.firstOrNull { it.title == t } ?: continue
            if (page.disambiguation || page.extract.isEmpty()) continue
            if (requireSaint && !looksLikeSaint(page.extract)) continue
            return page
        }
        return null
    }

    private suspend fun search(name: String, language: String): Page? {
        val toks = tokens(name)
        if (toks.isEmpty()) return null
        val url = "https://$language.wikipedia.org/w/api.php?$PROPS&generator=search&gsrlimit=5&gsrsearch=" + Net.enc(name)
        val json = Net.text(url) ?: return null
        val (pages, _) = parse(json, language) ?: return null
        for (page in pages) {
            val title = fold(page.title)
            if (!toks.all { title.contains(it) }) continue
            if (page.disambiguation || page.extract.isEmpty() || !looksLikeSaint(page.extract)) continue
            return page
        }
        return null
    }

    private fun parse(json: String, language: String): Pair<List<Page>, Map<String, String>>? {
        val root = try { Json.parse(json).asMap() } catch (e: Exception) { return null }
        val query = root["query"].asMap()
        if (query.isEmpty()) return null
        val aliases = HashMap<String, String>()
        for (k in listOf("normalized", "redirects")) {
            for (item in query[k].asList()) {
                val m = item.asMap()
                val from = m["from"] as? String
                val to = m["to"] as? String
                if (from != null && to != null) aliases[from] = to
            }
        }
        val pages = query["pages"].asList().map { it.asMap() }
            .sortedBy { (it["index"] as? Double) ?: 0.0 }
            .mapNotNull { p ->
                val title = p["title"] as? String ?: return@mapNotNull null
                if (p.containsKey("missing") || p.containsKey("invalid")) return@mapNotNull null
                val links = p["langlinks"].asList().mapNotNull { l ->
                    val m = l.asMap()
                    val lang = m["lang"] as? String
                    val t = m["title"] as? String
                    if (lang != null && t != null) lang to t else null
                }.toMap()
                Page(
                    title = title,
                    language = language,
                    extract = ((p["extract"] as? String) ?: "").trim(),
                    image = p["thumbnail"].asMap()["source"] as? String,
                    url = p["fullurl"] as? String,
                    links = links,
                    disambiguation = p["pageprops"].asMap().containsKey("disambiguation"),
                )
            }
        return pages to aliases
    }

    fun fold(s: String): String =
        Normalizer.normalize(s, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase()

    private val stopWords = setOf("saint", "sainte", "saints", "saintes", "the", "and", "les", "des", "de", "du",
        "la", "le", "et", "of", "with", "his", "her", "their", "avec", "ses", "leur")

    fun tokens(s: String): List<String> =
        fold(s).split(Regex("[^\\p{L}]+")).filter { it.length > 2 && it !in stopWords }

    private val saintWords = listOf("saint", "martyr", "apotre", "apostle", "prophet", "eveque", "bishop", "moine", "monk",
        "moniale", "nun", "ermite", "hermit", "patriarch", "ascet", "venere", "venerated", "orthodox", "pape", "pope",
        "theolog", "thaumaturge", "wonderworker", "diacre", "deacon", "pretre", "priest", "confess", "higoumene", "abbot",
        "abbess", "abbesse", "stylite", "eglise", "church", "chretien", "christian", "canonis", "fete", "feast", "icone", "icon")

    fun looksLikeSaint(extract: String): Boolean {
        val f = fold(extract.take(1200))
        return saintWords.any { f.contains(it) }
    }

    private fun readCached(file: File): SaintProfile? = try {
        if (!file.exists()) null else {
            val m = Json.parse(file.readText()).asMap()
            SaintProfile(
                m["title"] as String, m["name"] as String, m["extract"] as String,
                m["imageUrl"] as? String, m["pageUrl"] as? String, m["language"] as String,
            )
        }
    } catch (e: Exception) { null }

    private fun writeCached(file: File, p: SaintProfile) {
        fun q(s: String?) = if (s == null) "null" else "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""
        val text = "{\"title\":${q(p.title)},\"name\":${q(p.name)},\"extract\":${q(p.extract)}," +
            "\"imageUrl\":${q(p.imageUrl)},\"pageUrl\":${q(p.pageUrl)},\"language\":${q(p.language)}}"
        try { file.writeText(text) } catch (e: Exception) { }
    }
}

// ---------------------------------------------------------------------------
// Images (cache disque) et vies des saints
// ---------------------------------------------------------------------------

object Images {
    private val memory = android.util.LruCache<String, Bitmap>(40)

    suspend fun bitmap(url: String?, maxPixel: Int = 700): Bitmap? {
        if (url == null) return null
        val memKey = "$maxPixel|$url"
        memory.get(memKey)?.let { return it }
        val file = Net.cacheFile("img-", url)
        val data = if (file.exists()) file.readBytes() else Net.bytes(url)?.also { bytes -> runCatching { file.writeBytes(bytes) } }
        data ?: return null
        val bmp = withContext(Dispatchers.Default) { decode(data, maxPixel) } ?: return null
        memory.put(memKey, bmp)
        return bmp
    }

    private fun decode(data: ByteArray, maxPixel: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= maxPixel || bounds.outHeight / (sample * 2) >= maxPixel) sample *= 2
        val bmp = BitmapFactory.decodeByteArray(data, 0, data.size, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
        val longest = maxOf(bmp.width, bmp.height)
        if (longest <= maxPixel) return bmp
        val scale = maxPixel.toFloat() / longest
        return Bitmap.createScaledBitmap(bmp, (bmp.width * scale).toInt().coerceAtLeast(1), (bmp.height * scale).toInt().coerceAtLeast(1), true)
    }
}

object Orthocal {
    private val memory = HashMap<String, List<SaintStory>>()

    /** Retourne null en cas d'erreur réseau. */
    suspend fun stories(date: CivilDate, calendar: ChurchCalendar): List<SaintStory>? {
        val cal = if (calendar == ChurchCalendar.NEW) "gregorian" else "julian"
        val key = "$cal-${date.year}-${date.month}-${date.day}"
        memory[key]?.let { return it }
        val file = File(AppData.cacheDir, "orthocal-$key.json")
        val json = if (file.exists()) file.readText() else Net.text("https://orthocal.info/api/greek/$cal/${date.year}/${date.month}/${date.day}/", 20000)
        json ?: return null
        val list = try {
            Json.parse(json).asMap()["stories"].asList().mapNotNull { s ->
                val m = s.asMap()
                val title = m["title"] as? String ?: return@mapNotNull null
                val text = HtmlText.plain((m["story"] as? String) ?: "")
                if (text.isEmpty()) null else SaintStory(title, text)
            }
        } catch (e: Exception) { return null }
        if (!file.exists()) runCatching { file.writeText(json) }
        memory[key] = list
        return list
    }
}

object HtmlText {
    fun plain(html: String): String {
        var s = html
        for (b in listOf("<br>", "<br/>", "<br />", "</p>", "</div>", "</li>", "</h1>", "</h2>", "</h3>", "</h4>", "</blockquote>")) {
            s = s.replace(b, "\n\n", ignoreCase = true)
        }
        s = s.replace(Regex("<[^>]+>"), "")
        val entities = mapOf("&amp;" to "&", "&quot;" to "\"", "&apos;" to "'", "&#39;" to "'", "&lt;" to "<", "&gt;" to ">",
            "&nbsp;" to " ", "&rsquo;" to "’", "&lsquo;" to "‘", "&ldquo;" to "“", "&rdquo;" to "”", "&mdash;" to "—",
            "&ndash;" to "–", "&hellip;" to "…")
        for ((k, v) in entities) s = s.replace(k, v)
        s = Regex("&#(\\d+);").replace(s) { m -> m.groupValues[1].toIntOrNull()?.let { String(Character.toChars(it)) } ?: "" }
        s = s.replace(Regex("[ \\t]+"), " ")
        s = s.replace(Regex("\\n\\s*\\n\\s*(\\n\\s*)+"), "\n\n")
        return s.trim()
    }

    fun paragraphs(text: String): List<String> = text.split("\n\n").map { it.trim() }.filter { it.isNotEmpty() }
}
