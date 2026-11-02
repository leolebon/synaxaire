package org.synaxaire.calendrier.engine

/**
 * Petit lecteur JSON sans dépendance (utilisé par le moteur, testable hors Android).
 * Produit des Map<String, Any?>, List<Any?>, String, Double, Boolean ou null.
 */
object Json {
    fun parse(text: String): Any? = Parser(text).run {
        skip()
        val v = value()
        skip()
        v
    }

    private class Parser(val s: String) {
        var i = 0

        fun skip() {
            while (i < s.length && s[i].isWhitespace()) i++
        }

        fun value(): Any? {
            skip()
            if (i >= s.length) throw IllegalArgumentException("JSON incomplet")
            return when (s[i]) {
                '{' -> obj()
                '[' -> arr()
                '"' -> str()
                't' -> { expect("true"); true }
                'f' -> { expect("false"); false }
                'n' -> { expect("null"); null }
                else -> num()
            }
        }

        fun expect(word: String) {
            if (!s.startsWith(word, i)) throw IllegalArgumentException("JSON invalide à $i")
            i += word.length
        }

        fun obj(): Map<String, Any?> {
            val m = LinkedHashMap<String, Any?>()
            i++ // {
            skip()
            if (s[i] == '}') { i++; return m }
            while (true) {
                skip()
                val k = str()
                skip()
                if (s[i] != ':') throw IllegalArgumentException("':' attendu à $i")
                i++
                m[k] = value()
                skip()
                when (s[i]) {
                    ',' -> i++
                    '}' -> { i++; return m }
                    else -> throw IllegalArgumentException("',' ou '}' attendu à $i")
                }
            }
        }

        fun arr(): List<Any?> {
            val l = ArrayList<Any?>()
            i++ // [
            skip()
            if (s[i] == ']') { i++; return l }
            while (true) {
                l.add(value())
                skip()
                when (s[i]) {
                    ',' -> i++
                    ']' -> { i++; return l }
                    else -> throw IllegalArgumentException("',' ou ']' attendu à $i")
                }
            }
        }

        fun str(): String {
            if (s[i] != '"') throw IllegalArgumentException("'\"' attendu à $i")
            i++
            val b = StringBuilder()
            while (true) {
                val c = s[i++]
                when (c) {
                    '"' -> return b.toString()
                    '\\' -> {
                        when (val e = s[i++]) {
                            '"' -> b.append('"')
                            '\\' -> b.append('\\')
                            '/' -> b.append('/')
                            'b' -> b.append('\b')
                            'f' -> b.append('\u000C')
                            'n' -> b.append('\n')
                            'r' -> b.append('\r')
                            't' -> b.append('\t')
                            'u' -> {
                                b.append(s.substring(i, i + 4).toInt(16).toChar())
                                i += 4
                            }
                            else -> b.append(e)
                        }
                    }
                    else -> b.append(c)
                }
            }
        }

        fun num(): Double {
            val start = i
            while (i < s.length && (s[i].isDigit() || s[i] in "+-.eE")) i++
            return s.substring(start, i).toDouble()
        }
    }
}

@Suppress("UNCHECKED_CAST")
fun Any?.asMap(): Map<String, Any?> = (this as? Map<String, Any?>) ?: emptyMap()

@Suppress("UNCHECKED_CAST")
fun Any?.asList(): List<Any?> = (this as? List<Any?>) ?: emptyList()
