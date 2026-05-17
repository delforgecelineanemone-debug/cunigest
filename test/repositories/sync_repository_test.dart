// Tests : SyncRepository — file de synchronisation cloud.
// Risque cible : une entrée qui échoue en boucle (retry_count qui
// monte sans plafond) consomme la bande passante et bloque la queue.
// getPending doit exclure les abandonnées, et markFailed doit
// vraiment incrémenter retry_count.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/sync_entry.dart';
import 'package:gestion_cunicole/repositories/sync_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late SyncRepository repo;

  setUp(() async {
    db = await openTestDb();
    repo = SyncRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> enq() => repo.enqueue(
        tableName: 'lapins',
        rowId: 1,
        operation: 'insert',
        payload: {'id': 1, 'nom': 'A'},
      );

  group('markFailed', () {
    test('incrémente retry_count et stocke l\'erreur', () async {
      final id = await enq();
      await repo.markFailed(id, 'boom');
      await repo.markFailed(id, 'boom2');

      final row = (await db.query('sync_queue', where: 'id = ?', whereArgs: [id])).first;
      expect(row['retry_count'], 2);
      expect(row['error_message'], 'boom2');
      expect(row['synced_at'], isNull);
    });
  });

  group('markSynced', () {
    test('renseigne synced_at et efface error_message', () async {
      final id = await enq();
      await repo.markFailed(id, 'boom');
      await repo.markSynced(id);

      final row = (await db.query('sync_queue', where: 'id = ?', whereArgs: [id])).first;
      expect(row['synced_at'], isNotNull);
      expect(row['error_message'], isNull);
    });
  });

  group('getPending — exclusion abandonnées', () {
    test('retry_count > maxRetries → exclu du getPending', () async {
      final id1 = await enq();
      final id2 = await enq();

      // id2 dépasse la limite
      await db.update('sync_queue', {'retry_count': 11},
          where: 'id = ?', whereArgs: [id2]);

      final pending = await repo.getPending(maxRetries: 10);
      expect(pending.map((e) => e.id), [id1]);
    });

    test('retry_count exactement = maxRetries → inclus', () async {
      final id = await enq();
      await db.update('sync_queue', {'retry_count': 10},
          where: 'id = ?', whereArgs: [id]);
      final pending = await repo.getPending(maxRetries: 10);
      expect(pending.length, 1);
    });

    test('entrée déjà syncée → exclue', () async {
      final id = await enq();
      await repo.markSynced(id);
      expect(await repo.getPending(), isEmpty);
    });

    test('order ASC sur created_at (FIFO)', () async {
      final a = await enq();
      // Force un created_at antérieur pour b
      final b = await db.insert('sync_queue', {
        'table_name': 't', 'row_id': 1, 'operation': 'insert',
        'payload_json': '{}',
        'created_at': '1999-01-01T00:00:00.000',
        'retry_count': 0,
      });
      final pending = await repo.getPending();
      expect(pending.first.id, b);
      expect(pending.last.id, a);
    });
  });

  group('countPending / countAbandoned', () {
    test('comptages cohérents', () async {
      final id1 = await enq();
      final id2 = await enq();
      final id3 = await enq();
      await repo.markSynced(id3);
      await db.update('sync_queue', {'retry_count': 15},
          where: 'id = ?', whereArgs: [id2]);

      expect(await repo.countPending(), 2);
      expect(await repo.countAbandoned(maxRetries: 10), 1);
      expect(id1, isPositive);
    });
  });

  group('nettoyer', () {
    test('supprime uniquement les entrées syncées au-delà de la rétention',
        () async {
      final old = await enq();
      final recent = await enq();
      final pending = await enq();

      // old : syncée il y a 60j
      await db.update('sync_queue', {
        'synced_at': DateTime.now().subtract(const Duration(days: 60)).toIso8601String(),
      }, where: 'id = ?', whereArgs: [old]);

      // recent : syncée hier
      await db.update('sync_queue', {
        'synced_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      }, where: 'id = ?', whereArgs: [recent]);

      final n = await repo.nettoyer(joursRetention: 30);
      expect(n, 1);

      final restants =
          (await db.query('sync_queue')).map((r) => r['id'] as int).toSet();
      expect(restants, {recent, pending});
    });
  });

  group('config singleton', () {
    test('getConfig sur base seedée → ligne id=1 existante', () async {
      final c = await repo.getConfig();
      expect(c, isA<SyncConfig>());
      // Le seed la pré-remplit (peut-être avec serverUrl vide selon AppConfig).
    });

    test('updateConfig persiste', () async {
      const c = SyncConfig(email: 'a@b.c', nom: 'Test', passwordHash: 'h');
      await repo.updateConfig(c);
      final loaded = await repo.getConfig();
      expect(loaded.email, 'a@b.c');
      expect(loaded.nom, 'Test');
      expect(loaded.hasLocalAccount, isTrue);
    });
  });
}
