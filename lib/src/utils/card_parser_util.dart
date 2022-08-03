import 'dart:core';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ml_card_scanner/src/model/card_info.dart';
import 'package:ml_card_scanner/src/utils/string_extension.dart';

class CardParserUtil {
  final int _cardNumberLength = 16;
  final _textDetector = TextRecognizer(script: TextRecognitionScript.latin);

  Future<CardInfo?> detectCardContent(InputImage inputImage) async {
    var input = await _textDetector.processImage(inputImage);

    var clearElements = input.blocks
        .map(
          (e) => e.text.clean(),
        )
        .toList();

    try {
      var possibleCardNumber =
          clearElements.firstWhere((e) => (e.length == _cardNumberLength) && (int.tryParse(e) ?? -1) != -1);
      return CardInfo(number: possibleCardNumber, type: '', expiry: '');
    } catch (e, _) {}

    try {
      var possibleCardNumbers = clearElements.where((e) => (e.length == 4) && (int.tryParse(e) ?? -1) != -1);
      if (possibleCardNumbers.length == 4) {
        var cardNumber = possibleCardNumbers.join('');
        return CardInfo(number: cardNumber, type: '', expiry: '');
      }
    } catch (e, _) {}

    return null;
  }
}
