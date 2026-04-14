import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScreenshotAnalysisResult {
  final String? transactionId;
  final bool isDatePotentiallyOld;
  final bool isPayeeValid;
  final String rawText;

  ScreenshotAnalysisResult({
    this.transactionId,
    this.isDatePotentiallyOld = false,
    this.isPayeeValid = false,
    required this.rawText,
  });
}

class ScreenshotAnalyzer {
  static final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static Future<ScreenshotAnalysisResult> analyzePaymentScreenshot(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      final String text = recognizedText.text;
      
      // ─── Extract Transaction ID ───
      // Common UPI UTR is a 12-digit number: \b\d{12}\b
      // PhonePe transaction IDs often start with T followed by digits: \bT\d{15,22}\b
      String? extractedTxnId;

      final utrRegex = RegExp(r'(?<!\d)\d{12}(?!\d)');
      final phonePeRegex = RegExp(r'(?<![A-Za-z0-9])T\d{15,22}(?!\d)', caseSensitive: false);
      final paytmRegex = RegExp(r'(?<!\d)2\d{17}(?!\d)');

      // We'll prioritize the longer IDs or standard UTRs.
      if (phonePeRegex.hasMatch(text)) {
        extractedTxnId = phonePeRegex.firstMatch(text)?.group(0);
      } else if (paytmRegex.hasMatch(text)) {
        extractedTxnId = paytmRegex.firstMatch(text)?.group(0);
      } else if (utrRegex.hasMatch(text)) {
        final matches = utrRegex.allMatches(text).map((m) => m.group(0)!).toList();
        // Sometimes 12 digits can just be phone numbers or Aadhar etc.
        // We'll just take the first one found if there are any.
        if (matches.isNotEmpty) {
          extractedTxnId = matches.first;
        }
      }

      // ─── Analyze Date/Time ───
      // Check if it's potentially an old screenshot by looking for previous years
      // This is a rough heuristic.
      bool isOld = false;
      final currentYear = DateTime.now().year;
      // Look for explicit past years like 2021, 2022, 2023, etc.
      // (Assuming current year is at least 2024 realistically, but using dynamic checking)
      for (int year = 2020; year < currentYear; year++) {
        if (text.contains(year.toString())) {
          isOld = true;
          break;
        }
      }

      // ─── Payee Check ───
      final normalizedText = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      
      // Be more lenient due to OCR irregularities (e.g. "royal shubham" becomes "royalshubham", or just missing parts).
      final isPayeeValid = normalizedText.contains('royalshubhampixellabs') ||
                           normalizedText.contains('royalshubham') ||
                           normalizedText.contains('shubham');

      return ScreenshotAnalysisResult(
        transactionId: extractedTxnId,
        isDatePotentiallyOld: isOld,
        isPayeeValid: isPayeeValid,
        rawText: text,
      );
    } catch (e) {
      // If OCR completely fails or crashes (e.g. model not downloaded), we shouldn't hard-block 
      // the screenshot. We'll return true for isPayeeValid so it doesn't show the error, 
      // but without a transaction ID it will still ask them to type it.
      return ScreenshotAnalysisResult(
        rawText: '',
        isPayeeValid: true, // Allow fallback if OCR itself crashes
      );
    }
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
