import 'package:string_similarity/string_similarity.dart';
import 'package:english_words/english_words.dart';

class TextCorrectionService {
  // Load the dictionary into a fast-lookup Set once (contains ~30k+ words)
  static final Set<String> _dictionary = Set.from(all.map((w) => w.toLowerCase()));

  static String correct(String rawText) {
    String text = rawText;

    // 1. Structural Formatting (Your code)
    text = _fixBrokenWords(text);
    text = _unwrapLines(text); 
    
    // 2. Math & Typographic Symbols (Added for your special symbols)
    text = _formatMathAndSymbols(text); 
    
    // 3. Spacing & Punctuation (Your code)
    text = _fixSpacing(text);
    text = _fixPunctuation(text);
    
    // 4. ACTUAL SPELLING & GRAMMAR CORRECTION (New)
    text = _correctOcrTypos(text); 
    text = _fixBasicGrammar(text);   
    
    // 5. Final Cleanup (Your code)
    text = _fixLineBreaks(text);
    text = _fixCapitalization(text);

    return text.trim();
  }

  // ─── NEW: SPELLING & GRAMMAR ──────────────────────────────────────────────────

  // Smart Dictionary & OCR-Typo Correction
  static String _correctOcrTypos(String text) {
    return text.replaceAllMapped(RegExp(r'[A-Za-z0-9]+'), (match) {
      String original = match.group(0)!;
      if (RegExp(r'^\d+$').hasMatch(original)) return original; // Skip pure numbers

      String lower = original.toLowerCase();
      if (_dictionary.contains(lower)) return original; // Word is already perfect

      // Try swapping common OCR mistakes
      String swapped = lower
          .replaceAll('0', 'o')
          .replaceAll('1', 'l')
          .replaceAll('5', 's')
          .replaceAll('8', 'b')
          .replaceAll('rn', 'm')
          .replaceAll('cl', 'd')
          .replaceAll('vv', 'w');

      if (_dictionary.contains(swapped)) {
        return _restoreCase(original, swapped);
      }

      // Fallback: Fuzzy Mathing for misspellings (e.g. "langauge" -> "language")
      if (original.length > 3 && RegExp(r'[A-Za-z]').hasMatch(original)) {
        List<String> candidates = _dictionary.where((w) =>
            (w.length - original.length).abs() <= 1
        ).toList();

        if (candidates.isNotEmpty) {
          var matchResult = swapped.bestMatch(candidates); 
          if (matchResult.bestMatch.rating! > 0.82) {
            return _restoreCase(original, matchResult.bestMatch.target!);
          }
        }
      }
      return original;
    });
  }

  static String _restoreCase(String original, String corrected) {
    if (original.isEmpty) return corrected;
    if (original.toUpperCase() == original && original.contains(RegExp(r'[A-Z]'))) {
      return corrected.toUpperCase();
    }
    if (original[0].toUpperCase() == original[0]) {
      return corrected[0].toUpperCase() + (corrected.length > 1 ? corrected.substring(1) : '');
    }
    return corrected;
  }

  // Offline Grammar Checker (Rule-Based)
  static String _fixBasicGrammar(String text) {
    // Fix standalone 'i' -> 'I'
    text = text.replaceAllMapped(RegExp(r'\b[iI]\b'), (m) => 'I');

    // Fix "a" vs "an" before vowels (e.g. "a apple" -> "an apple")
    text = text.replaceAllMapped(
      RegExp(r'\b[Aa]\s+([aeiouAEIOU][a-z]+)\b'),
      (m) {
        String nextWord = m[1]!.toLowerCase();
        if (nextWord.startsWith('u') && !nextWord.startsWith('um') && !nextWord.startsWith('un')) return 'a ${m[1]}'; 
        if (nextWord.startsWith('one') || nextWord.startsWith('onc')) return 'a ${m[1]}'; 
        return 'an ${m[1]}';
      },
    );

    // Fix "an" before consonants (e.g. "an car" -> "a car")
    text = text.replaceAllMapped(
      RegExp(r'\b[Aa]n\s+([bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ][a-z]+)\b'),
      (m) {
        String nextWord = m[1]!.toLowerCase();
        if (nextWord.startsWith('ho')) return 'an ${m[1]}'; // honor, hour
        return 'a ${m[1]}';
      },
    );

    // Remove accidental repeated words (e.g., "the the")
    text = text.replaceAllMapped(RegExp(r'\b([A-Za-z]+)\s+\1\b', caseSensitive: false), (m) => m[1]!);

    return text;
  }

  // Math & Typographic Symbols Formatter
  static String _formatMathAndSymbols(String text) {
    text = text.replaceAllMapped(
      RegExp(r'([A-Za-z0-9])([+=×÷±≈≠≤≥<>˂˃˄˅％＆＊])([A-Za-z0-9])'),
      (m) => '${m[1]} ${m[2]} ${m[3]}',
    );
    text = text.replaceAllMapped(
      RegExp(r'^([·•\-‒–—―․‥…‧])\s*([a-zA-Z])', multiLine: true),
      (m) => '${m[1]} ${m[2]}',
    );
    return text;
  }

  // ─── YOUR EXISTING FORMATTING CODE (Safely updated for symbols) ─────────────────

  static String _fixBrokenWords(String text) {
    return text.replaceAllMapped(RegExp(r'(\w+)-\n(\w+)'), (m) => '${m[1]}${m[2]}');
  }

  static String _unwrapLines(String text) {
    return text.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ');
  }

  static String _fixSpacing(String text) {
    text = text.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    text = text.replaceAllMapped(RegExp(r'(\d)\.([A-Za-z])'), (m) => '${m[1]}. ${m[2]}');
    text = text.replaceAll(RegExp(r' {2,}'), ' ');

    // Adjusted to safely handle your special symbols
    text = text.replaceAllMapped(RegExp(r' ([.,;:!?．：；？＠、。〃〝〞︰])'), (m) => m[1]!);
    text = text.replaceAllMapped(RegExp(r'([.,;:!?．：；？＠、。〃〝〞︰])([A-Za-z])'), (m) => '${m[1]} ${m[2]}');

    return text;
  }

  static String _fixPunctuation(String text) {
    text = text.replaceAll(RegExp(r'\.{3,}'), '…'); // Standardize ellipses
    text = text.replaceAll(RegExp(r'\.{2,}'), '.');
    text = text.replaceAll(RegExp(r"(\w) ' (\w)"), r"\1'\2");
    text = text.replaceAll('``', '"');
    text = text.replaceAll("''", '"');
    text = text.replaceAllMapped(RegExp(r'\b1([a-zA-Z]{2,})\b'), (m) => 'l${m[1]}');
    return text;
  }

  static String _fixLineBreaks(String text) {
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.split('\n').map((line) => line.trimRight()).join('\n');
  }

  static String _fixCapitalization(String text) {
    if (text.isEmpty) return text;
    text = text[0].toUpperCase() + text.substring(1);
    
    // Capitalize after ". ! ?" and your new symbols "。 ？ ！ …"
    text = text.replaceAllMapped(
      RegExp(r'([.!?。？！…])\s+([a-z])'),
      (m) => '${m[1]} ${m[2]!.toUpperCase()}',
    );
    return text;
  }
}