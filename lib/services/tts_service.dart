import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

String cleanEnglishTextForTts(String text) {
  final cleaned = text
      .replaceAll(RegExp(r'/[^/\r\n]+/'), ' ')
      .replaceAll(RegExp(r'\([^)]*[가-힣ㄱ-ㅎㅏ-ㅣ][^)]*\)'), ' ')
      .replaceAll(RegExp(r'[가-힣ㄱ-ㅎㅏ-ㅣ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return RegExp(r'[A-Za-z]').hasMatch(cleaned) ? cleaned : '';
}

abstract class EnglishTtsEngine {
  Future<void> stop();
  Future<void> setLanguage(String language);
  Future<void> setVoice(Map<String, String> voice);
  Future<void> setSpeechRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> setVolume(double volume);
  Future<void> awaitSpeakCompletion(bool enabled); 
  Future<dynamic> getVoices();
  Future<void> speak(String text);
}

class _FlutterEnglishTtsEngine implements EnglishTtsEngine {
  _FlutterEnglishTtsEngine(this._tts);

  final FlutterTts _tts;

  @override
  Future<void> stop() async => _tts.stop();

  @override
  Future<void> setLanguage(String language) async => _tts.setLanguage(language);

  @override
  Future<void> setVoice(Map<String, String> voice) async =>
      _tts.setVoice(voice);

  @override
  Future<void> setSpeechRate(double rate) async => _tts.setSpeechRate(rate);

  @override
  Future<void> setPitch(double pitch) async => _tts.setPitch(pitch);

  @override
  Future<void> setVolume(double volume) async => _tts.setVolume(volume);

  @override
  Future<void> awaitSpeakCompletion(bool enabled) async =>
      _tts.awaitSpeakCompletion(enabled);

  @override
  Future<dynamic> getVoices() async => _tts.getVoices;

  @override
  Future<void> speak(String text) async => _tts.speak(text);
}

class EnglishTtsController {
  EnglishTtsController(this._engine);

  final EnglishTtsEngine _engine;
  late final Future<void> _initializeFuture = _initialize();
  Map<String, String>? _selectedVoice;
  int _requestId = 0;

  Future<void> initialize() => _initializeFuture;

  Future<void> _initialize() async {
    await _engine.setLanguage('en-US');
    await _engine.setSpeechRate(0.88);
    await _engine.setPitch(1.0);
    await _engine.setVolume(1.0);
    await _engine.awaitSpeakCompletion(true);
    _selectedVoice = await _findEnglishVoice();
    final voice = _selectedVoice;
    if (voice != null) await _engine.setVoice(voice);
    _log(
      '[tts] initialized language=en-US voice=${voice?['name'] ?? 'system'}',
    );
  }

  Future<Map<String, String>?> _findEnglishVoice() async {
    try {
      final rawVoices = await _engine.getVoices();
      if (rawVoices is! List) return null;
      final voices = rawVoices.whereType<Map>().toList(growable: false);

      Map<dynamic, dynamic>? findLocale(String wanted) {
        for (final voice in voices) {
          final locale = (voice['locale'] ?? voice['language'] ?? '')
              .toString()
              .toLowerCase()
              .replaceAll('_', '-');
          if (locale == wanted) return voice;
        }
        return null;
      }

      var selected = findLocale('en-us') ?? findLocale('en-gb');
      if (selected == null) {
        for (final voice in voices) {
          final locale = (voice['locale'] ?? voice['language'] ?? '')
              .toString()
              .toLowerCase();
          if (locale.startsWith('en')) {
            selected = voice;
            break;
          }
        }
      }

      final name = selected?['name']?.toString() ?? '';
      final locale =
          (selected?['locale'] ?? selected?['language'])?.toString() ?? '';
      if (name.isEmpty || locale.isEmpty) return null;
      return {'name': name, 'locale': locale};
    } catch (error) {
      _log('[tts] English voice lookup failed: $error');
      return null;
    }
  }

  Future<void> speakEnglish(String text) async {
    final requestId = ++_requestId;
    await _initializeFuture;
    if (requestId != _requestId) return;

    await _engine.stop();
    if (requestId != _requestId) return;
    await _engine.setLanguage('en-US');
    final voice = _selectedVoice;
    if (voice != null) await _engine.setVoice(voice);
    if (requestId != _requestId) return;

    _log('[tts] speakEnglish text=$text');
    await _engine.speak(text);
  }

  Future<void> stop() async {
    _requestId++;
    await _engine.stop();
  }

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }
}

class TtsService {
  static final EnglishTtsController _controller = EnglishTtsController(
    _FlutterEnglishTtsEngine(FlutterTts()),
  );

  static Future<void> initialize() => _controller.initialize();

  static Future<void> speakEnglish(String text) async {
    final cleanText = cleanEnglishTextForTts(text);
    if (cleanText.isEmpty) return;
    try {
      await _controller.speakEnglish(cleanText);
    } catch (error) {
      if (kDebugMode) debugPrint('[tts] speakEnglish failed: $error');
    }
  }

  static Future<void> speakEnglishText(String text) => speakEnglish(text);

  static Future<void> stop() => _controller.stop();
}
