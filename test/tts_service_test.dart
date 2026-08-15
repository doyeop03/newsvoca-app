import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/services/tts_service.dart';

void main() {
  group('cleanEnglishTextForTts', () {
    test('removes IPA and Korean text while preserving English', () {
      expect(
        cleanEnglishTextForTts(
          'inflation /ɪnˈfleɪʃən/ (물가 상승) means rising prices.',
        ),
        'inflation means rising prices.',
      );
    });

    test('does not send Korean-only text to TTS', () {
      expect(cleanEnglishTextForTts('물가 상승, 인플레이션'), isEmpty);
    });

    test('keeps numbers and punctuation in an English sentence', () {
      expect(
        cleanEnglishTextForTts('Prices rose 4.3% in July.'),
        'Prices rose 4.3% in July.',
      );
    });

    test('keeps hyphens, apostrophes, and acronyms unchanged', () {
      expect(
        cleanEnglishTextForTts("on-device AI, DRAM, F-47, and users' data"),
        "on-device AI, DRAM, F-47, and users' data",
      );
    });
  });

  group('EnglishTtsController', () {
    test('first playback waits for English initialization', () async {
      final engine = _FakeEnglishTtsEngine();
      final controller = EnglishTtsController(engine);

      await controller.speakEnglish('benchmark interest rate');

      final speakIndex = engine.calls.indexOf('speak:benchmark interest rate');
      expect(speakIndex, greaterThan(0));
      expect(
        engine.calls.take(speakIndex),
        containsAllInOrder([
          'language:en-US',
          'rate:0.72',
          'completion:true',
          'voice:Samantha:en-US',
          'stop',
          'language:en-US',
          'voice:Samantha:en-US',
        ]),
      );
      expect(engine.calls, isNot(contains('voice:Korean:ko-KR')));
    });

    test('every playback stops previous audio and reapplies English', () async {
      final engine = _FakeEnglishTtsEngine();
      final controller = EnglishTtsController(engine);

      await controller.speakEnglish('first word');
      await controller.speakEnglish('second word');

      expect(engine.calls.where((call) => call == 'stop'), hasLength(2));
      expect(
        engine.calls.where((call) => call == 'language:en-US'),
        hasLength(3),
      );
      expect(
        engine.calls,
        containsAllInOrder([
          'speak:first word',
          'stop',
          'language:en-US',
          'speak:second word',
        ]),
      );
    });
  });
}

class _FakeEnglishTtsEngine implements EnglishTtsEngine {
  final List<String> calls = [];

  @override
  Future<void> awaitSpeakCompletion(bool enabled) async {
    calls.add('completion:$enabled');
  }

  @override
  Future<dynamic> getVoices() async => [
    {'name': 'Korean', 'locale': 'ko-KR'},
    {'name': 'Samantha', 'locale': 'en-US'},
  ];

  @override
  Future<void> setLanguage(String language) async {
    calls.add('language:$language');
  }

  @override
  Future<void> setPitch(double pitch) async {
    calls.add('pitch:$pitch');
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    calls.add('rate:$rate');
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    calls.add('voice:${voice['name']}:${voice['locale']}');
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('volume:$volume');
  }

  @override
  Future<void> speak(String text) async {
    calls.add('speak:$text');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }
}
