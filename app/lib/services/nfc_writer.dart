import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import '../link/link_codec.dart';

enum NfcStatus { ready, disabled, unsupported }

class NfcWriteException implements Exception {
  const NfcWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Writes a card's short link to a tag as a single NDEF URI record.
/// The tag is never locked (no makeReadOnly / formatReadOnly), so writing
/// another card later simply replaces the link.
class NfcWriter {
  /// When the last successful write happened. The tag is usually still against the
  /// phone right after, and Android would open it again.
  DateTime? lastWrite;

  Future<NfcStatus> status() async {
    try {
      final a = await NfcManager.instance.checkAvailability();
      return switch (a) {
        NfcAvailability.enabled => NfcStatus.ready,
        NfcAvailability.disabled => NfcStatus.disabled,
        _ => NfcStatus.unsupported,
      };
    } catch (_) {
      return NfcStatus.unsupported;
    }
  }

  /// Waits for a tag, asks [recordFor] for a record that fits the tag's NDEF capacity,
  /// writes it, and completes with that capacity. Call [cancel] to stop waiting.
  Future<int> write(List<NdefRecord> Function(int ndefMaxSize) recordsFor) {
    final done = Completer<int>();
    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (tag) async {
        try {
          final ndef = NdefAndroid.from(tag);
          int capacity;
          if (ndef != null) {
            if (!ndef.isWritable) throw const NfcWriteException('This tag is locked and can’t be written.');
            capacity = ndef.maxSize;
            final message = NdefMessage(records: recordsFor(capacity));
            if (message.byteLength > capacity) throw const NfcWriteException('This tag is too small for a card.');
            await ndef.writeNdefMessage(message);
          } else {
            final formatable = NdefFormatableAndroid.from(tag);
            if (formatable == null) throw const NfcWriteException('This tag doesn’t support NFC links (NDEF).');
            // A blank tag can't report its size yet; assume the smallest common sticker (NTAG213).
            capacity = 137;
            await formatable.format(NdefMessage(records: recordsFor(capacity)));
          }
          await NfcManager.instance.stopSession();
          lastWrite = DateTime.now();
          if (!done.isCompleted) done.complete(capacity);
        } on NfcWriteException catch (e) {
          await NfcManager.instance.stopSession();
          if (!done.isCompleted) done.completeError(e);
        } catch (_) {
          // Usually the tag moved away mid-write. The session stays open, so holding it again retries.
        }
      },
    );
    return done.future;
  }

  Future<void> cancel() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  /// NDEF well-known URI record ("U") with the standard prefix compression.
  /// A card stored as raw bytes in an NDEF external-type record (bibblebob.app:card).
  /// No web link: Android hands it straight to the app, which reads it offline.
  static NdefRecord cardRecord(Uint8List bytes) => NdefRecord(
    typeNameFormat: TypeNameFormat.external,
    type: Uint8List.fromList(utf8.encode(LinkCodec.tagRecordType)),
    identifier: Uint8List(0),
    payload: bytes,
  );

  static NdefRecord uriRecord(String url) {
    const prefixes = ['https://www.', 'http://www.', 'https://', 'http://'];
    const codes = [0x02, 0x01, 0x04, 0x03];
    var code = 0x00;
    var rest = url;
    for (var i = 0; i < prefixes.length; i++) {
      if (url.startsWith(prefixes[i])) {
        code = codes[i];
        rest = url.substring(prefixes[i].length);
        break;
      }
    }
    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x55]),
      identifier: Uint8List(0),
      payload: Uint8List.fromList([code, ...utf8.encode(rest)]),
    );
  }
}
