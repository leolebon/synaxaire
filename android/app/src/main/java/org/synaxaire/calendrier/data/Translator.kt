package org.synaxaire.calendrier.data

import com.google.android.gms.tasks.Task
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Traduction sur l'appareil (ML Kit) : fr, en, el, ru, ro, ar sont pris en charge. */
object Translator {
    suspend fun translate(paragraphs: List<String>, from: String, to: String): List<String>? {
        val src = TranslateLanguage.fromLanguageTag(from) ?: return null
        val tgt = TranslateLanguage.fromLanguageTag(to) ?: return null
        if (src == tgt) return paragraphs
        val options = TranslatorOptions.Builder().setSourceLanguage(src).setTargetLanguage(tgt).build()
        val client = Translation.getClient(options)
        return try {
            client.downloadModelIfNeeded(DownloadConditions.Builder().build()).await()
            paragraphs.map { client.translate(it).await() }
        } catch (e: Exception) {
            null
        } finally {
            client.close()
        }
    }
}

private suspend fun <T> Task<T>.await(): T = suspendCancellableCoroutine { cont ->
    addOnSuccessListener { result -> cont.resume(result) }
    addOnFailureListener { e -> cont.resumeWithException(e) }
    addOnCanceledListener { cont.cancel() }
}
