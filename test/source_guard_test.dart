import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  group('release safety guards', () {
    test('aucun secret Supabase privilégié hardcodé', () {
      // L'URL projet + la clé ANON sont PUBLIQUES par design (protégées
      // par RLS côté serveur) — leur présence en defaultValue est un
      // choix d'architecture assumé. Ce qui ne doit JAMAIS apparaître :
      // la Service Role Key (JWT role=service_role) qui contourne RLS.
      final files = [
        'lib/utils/app_config.dart',
        'lib/database/db_helper.dart',
        'lib/database/schema.dart',
        'lib/services/sync_service.dart',
        'lib/services/account_service.dart',
      ].map(read).join('\n');

      // Un JWT service_role contient la claim "role":"service_role".
      // base64 de '"role":"service_role"' → recherche du segment décodé
      // serait coûteuse ; on rejette toute occurrence littérale.
      expect(files.contains('service_role'), isFalse,
          reason: 'Service Role Key détectée — elle contourne RLS, '
              'ne doit jamais être embarquée dans le code mobile.');
      expect(files.toLowerCase().contains('supabase_service_role'), isFalse);
    });

    test('sync pull does not use SQLite REPLACE', () {
      final syncService = read('lib/services/sync_service.dart');
      expect(syncService, isNot(contains('ConflictAlgorithm.replace')));
      expect(syncService, contains('await executor.update('));
      expect(syncService, contains('await executor.insert(table, clean)'));
    });

    test('schema version a jour avec branche de migration', () {
      final schema = read('lib/database/schema.dart');
      expect(schema, contains('const int kCurrentDbVersion = 20'));
      expect(schema, contains("devise TEXT DEFAULT 'FCFA'"));
      expect(schema, contains('if (oldVersion < 10)'));
      expect(schema, contains('if (oldVersion < 11)'));
      expect(schema, contains('if (oldVersion < 16)'));
      // V17 — soft-delete ; V18 — backoff sync_queue ; V19 — FCFA défaut ;
      // V20 — table conflict_log (audit multi-device).
      expect(schema, contains('if (oldVersion < 17)'));
      expect(schema, contains('if (oldVersion < 18)'));
      expect(schema, contains('if (oldVersion < 19)'));
      expect(schema, contains('if (oldVersion < 20)'));
      expect(schema, contains('ALTER TABLE reglages ADD COLUMN devise'));
      expect(schema, contains('ALTER TABLE sync_config ADD COLUMN password_hash'));
      expect(schema, contains('ALTER TABLE lapins ADD COLUMN cause_mortalite'));
      expect(schema, contains('applySoftDeleteColumns'));
      expect(schema, contains('createV20Tables'));
    });

    test('chaque version du schéma a sa branche de migration', () {
      final schema = read('lib/database/schema.dart');
      final match = RegExp(r'const int kCurrentDbVersion = (\d+)')
          .firstMatch(schema);
      expect(match, isNotNull);
      final version = int.parse(match!.group(1)!);
      // Toute version N (à partir de 2) doit avoir un `oldVersion < N`.
      for (var v = 2; v <= version; v++) {
        expect(schema, contains('oldVersion < $v'),
            reason: 'Migration manquante pour la version $v');
      }
    });

    test('release builds cannot silently use debug signing', () {
      final gradle = read('android/app/build.gradle.kts');
      final gitignore = read('.gitignore');

      expect(gradle, contains('Release build blocked'));
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")\n            }')));
      expect(gitignore, contains('/android/key.properties'));
      expect(gitignore, contains('/android/*.jks'));
    });

    // ──────────────────────────────────────────────────────────
    // Design system guard : pas de magic Material colors dans
    // les briques UI réutilisables (cassent le thème sombre +
    // empêchent l'évolution centralisée de la palette).
    // ──────────────────────────────────────────────────────────
    test('design system : aucune magic Material color dans atoms/molecules/organisms/widgets', () {
      // Whitelist intentionnelle :
      // - Colors.white / Colors.black : utilisés sur fonds colorés sémantiques
      //   (texte sur badge primary, overlay modal) où ils sont volontaires.
      // - Colors.transparent : utilisé pour cacher le background d'un Container.
      // Tout le reste doit passer par CuColors.* ou context.cu*.
      final forbidden = RegExp(
        r'\bColors\.('
        r'red|blue|pink|green|grey|gray|indigo|orange|purple|yellow|cyan|'
        r'amber|brown|teal|lime|'
        r'deepOrange|deepPurple|lightBlue|lightGreen|blueGrey'
        r')\b',
      );

      final dirs = [
        Directory('lib/ui/atoms'),
        Directory('lib/ui/molecules'),
        Directory('lib/ui/organisms'),
        Directory('lib/ui/widgets'),
      ];

      final violations = <String>[];
      for (final dir in dirs) {
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final content = entity.readAsStringSync();
          for (final match in forbidden.allMatches(content)) {
            // Numéro de ligne approximatif : nombre de \n avant le match.
            final line = '\n'.allMatches(content.substring(0, match.start)).length + 1;
            violations.add('${entity.path}:$line  →  ${match.group(0)}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Magic Material colors interdites dans le design system.\n'
            'Utiliser CuColors.* (ex: CuColors.danger, CuColors.sexeMale) '
            'ou les helpers context.cu* (ex: context.cuTextSecondary).\n\n'
            'Violations :\n${violations.join("\n")}',
      );
    });
  });
}
