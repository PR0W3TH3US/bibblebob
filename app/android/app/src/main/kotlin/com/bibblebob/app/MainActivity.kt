package com.bibblebob.app

import android.content.Intent
import android.net.Uri
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.os.Build
import android.os.Bundle
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        translateCardTag(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        translateCardTag(intent)
        super.onNewIntent(intent)
    }

    /**
     * A tapped bibblebob tag arrives as NDEF_DISCOVERED with the card bytes in an external
     * record. Rewrite it into the same card link the Dart side already handles
     * (https://bibblebob.pages.dev/c#<base64url bytes>). Nothing is opened in a browser.
     */
    private fun translateCardTag(intent: Intent?) {
        if (intent?.action != NfcAdapter.ACTION_NDEF_DISCOVERED) return
        val messages: Array<out Any>? =
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES, NdefMessage::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
            }
        val record = messages
            ?.filterIsInstance<NdefMessage>()
            ?.flatMap { it.records.asList() }
            ?.firstOrNull {
                it.tnf == NdefRecord.TNF_EXTERNAL_TYPE &&
                    String(it.type, Charsets.US_ASCII).equals(CARD_TYPE, ignoreCase = true)
            } ?: return
        val payload = Base64.encodeToString(record.payload, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
        intent.action = Intent.ACTION_VIEW
        intent.data = Uri.parse("$SITE/c#$payload")
    }

    private companion object {
        const val CARD_TYPE = "bibblebob.app:card"
        const val SITE = "https://bibblebob.pages.dev"
    }
}
