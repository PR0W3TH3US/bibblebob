import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../data/file_store.dart';
import 'card_text_parser.dart';

class ScanResult {
  const ScanResult(this.photoName, this.parsed);
  final String photoName;
  final ParsedCard parsed;
}

/// Camera photo of a paper card + on-device text recognition (ML Kit, works offline).
class CardScanner {
  CardScanner(this._files);
  final FileStore _files;

  Future<ScanResult?> scan() async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 85,
    );
    if (shot == null) return null;
    final photo = await _files.copyIn(File(shot.path), prefix: 'scan');

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(_files.file(photo).path));
      final lines = [
        for (final block in result.blocks)
          for (final line in block.lines) OcrLine(line.text, height: line.boundingBox.height),
      ];
      return ScanResult(photo, CardTextParser.parse(lines));
    } catch (_) {
      // Recognition failed: still keep the photo and let the user type.
      return ScanResult(photo, const ParsedCard());
    } finally {
      await recognizer.close();
    }
  }
}
