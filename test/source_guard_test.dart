import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  group('release safety guards', () {
    test('Supabase project secrets are not hardcoded', () {
      final files = [
        'lib/utils/app_config.dart',
        'lib/database/db_helper.dart',
        'lib/database/schema.dart',
      ].map(read).join('\n');

      expect(RegExp(r'https://[a-z0-9]+\.supabase\.co').hasMatch(files), isFalse);
      expect(RegExp(r'eyJ[A-Za-z0-9_-]{20,}\.').hasMatch(files), isFalse);
      expect(files, contains("defaultValue: ''"));
    });

    test('sync pull does not use SQLite REPLACE', () {
      final syncService = read('lib/services/sync_service.dart');
      expect(syncService, isNot(contains('ConflictAlgorithm.replace')));
      expect(syncService, contains('await executor.update('));
      expect(syncService, contains('await executor.insert(table, clean)'));
    });

    test('schema version a jour avec branche de migration', () {
      final schema = read('lib/database/schema.dart');
      expect(schema, contains('const int kCurrentDbVersion = 11'));
      expect(schema, contains("devise TEXT DEFAULT '€'"));
      expect(schema, contains('if (oldVersion < 10)'));
      expect(schema, contains('if (oldVersion < 11)'));
      expect(schema, contains('ALTER TABLE reglages ADD COLUMN devise'));
      expect(schema, contains('ALTER TABLE sync_config ADD COLUMN password_hash'));
    });

    test('release builds cannot silently use debug signing', () {
      final gradle = read('android/app/build.gradle.kts');
      final gitignore = read('.gitignore');

      expect(gradle, contains('Release build blocked'));
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")\n            }')));
      expect(gitignore, contains('/android/key.properties'));
      expect(gitignore, contains('/android/*.jks'));
    });
  });
}
