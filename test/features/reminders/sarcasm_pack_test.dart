import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/reminders/models/sarcasm_pack.dart';
import 'package:unshrimp_app/features/reminders/repositories/fallback_sarcasm_lines.dart';
import 'package:unshrimp_app/features/reminders/repositories/sarcasm_pack_repository.dart';

import 'fakes.dart';

String _pack(String active) => jsonEncode({
  'active': active,
  'packs': {
    'default': ['Sit up.'],
    'halloween': ['Boo.', 'Even zombies stand straighter.'],
  },
});

void main() {
  group('SarcasmPack.tryParse', () {
    test('returns the active pack', () {
      final pack = SarcasmPack.tryParse(_pack('halloween'))!;
      expect(pack.active, 'halloween');
      expect(pack.lines, ['Boo.', 'Even zombies stand straighter.']);
    });

    test('falls back to default when the active pack is missing', () {
      final pack = SarcasmPack.tryParse(_pack('xmas'))!;
      expect(pack.active, 'default');
      expect(pack.lines, ['Sit up.']);
    });

    test('rejects empty, malformed or line-less values', () {
      expect(SarcasmPack.tryParse(null), isNull);
      expect(SarcasmPack.tryParse(''), isNull);
      expect(SarcasmPack.tryParse('not json'), isNull);
      expect(SarcasmPack.tryParse('{"packs": {"default": []}}'), isNull);
    });
  });

  group('SarcasmPackRepository', () {
    SarcasmPackRepository repo(
      FakeReminderPreferences prefs, {
      String? remote,
      Object? remoteError,
      List<String> cms = const [],
    }) => SarcasmPackRepository(
      prefs,
      readConfig: (_) async {
        if (remoteError != null) throw remoteError;
        return remote;
      },
      readCms: (_) async => cms,
    );

    test('uses Remote Config and caches it', () async {
      final prefs = FakeReminderPreferences();

      final pack = await repo(prefs, remote: _pack('halloween')).loadPack();

      expect(pack.active, 'halloween');
      expect(pack.lines, ['Boo.', 'Even zombies stand straighter.']);
      expect(prefs.pack, _pack('halloween'));
    });

    test('offline: uses the cached pack', () async {
      final prefs = FakeReminderPreferences(pack: _pack('default'));

      final pack = await repo(
        prefs,
        remoteError: Exception('offline'),
        cms: ['From CMS'],
      ).loadPack();

      expect(pack.lines, ['Sit up.']);
    });

    test('no config and no cache: uses the CMS', () async {
      final pack = await repo(
        FakeReminderPreferences(),
        remote: '',
        cms: ['From CMS'],
      ).loadPack();

      expect(pack.active, 'default');
      expect(pack.lines, ['From CMS']);
    });

    test('nothing anywhere: uses the bundled lines', () async {
      final pack = await repo(FakeReminderPreferences()).loadPack();

      expect(pack.active, 'default');
      expect(pack.lines, fallbackSarcasmLines);
    });
  });
}
