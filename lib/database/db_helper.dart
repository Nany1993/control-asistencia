import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'referential_integrity_exception.dart';
import '../models/asistencia_capacitacion.dart';
import '../models/capacitacion.dart';
import '../models/empleado.dart';
import '../models/empresa.dart';
import '../models/registro.dart';
import '../models/turno.dart';

class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<void> closeForBackup() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  static Future<String> databaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'control_asistencia.db');
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'control_asistencia.db');

    return openDatabase(
      path,
      version: 8,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE empleados ADD COLUMN tipo_documento TEXT NOT NULL DEFAULT 'CC'",
          );
          await db.execute(
            "ALTER TABLE empleados ADD COLUMN numero_documento TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE empleados ADD COLUMN es_externo INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS turnos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              empresa_id INTEGER NOT NULL,
              nombre TEXT NOT NULL,
              hora_entrada TEXT NOT NULL,
              hora_salida TEXT NOT NULL,
              tolerancia_minutos INTEGER NOT NULL DEFAULT 15,
              dias_semana TEXT NOT NULL DEFAULT '1,2,3,4,5',
              FOREIGN KEY (empresa_id) REFERENCES empresas(id)
            )
          ''');
          await db.execute(
            'ALTER TABLE empleados ADD COLUMN turno_id INTEGER',
          );
          await db.execute(
            'ALTER TABLE registros ADD COLUMN observacion TEXT',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE turnos ADD COLUMN hora_almuerzo_inicio TEXT',
          );
          await db.execute(
            'ALTER TABLE turnos ADD COLUMN hora_almuerzo_fin TEXT',
          );
          await db.execute(
            'ALTER TABLE registros ADD COLUMN motivo_salida TEXT',
          );
          await db.execute(
            'ALTER TABLE registros ADD COLUMN radicado TEXT',
          );
        }
        if (oldVersion < 6) {
          await _createCapacitacionTables(db);
        }
        if (oldVersion < 7) {
          await _createEmpleadoTurnosTable(db);
          await db.execute(
            'ALTER TABLE registros ADD COLUMN turno_id INTEGER',
          );
          await db.execute('''
            INSERT OR IGNORE INTO empleado_turnos (empleado_id, turno_id)
            SELECT id, turno_id FROM empleados WHERE turno_id IS NOT NULL
          ''');
        }
        if (oldVersion < 8) {
          await _migrateTurnosSinEmpresa(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE empresas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE turnos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        hora_entrada TEXT NOT NULL,
        hora_salida TEXT NOT NULL,
        tolerancia_minutos INTEGER NOT NULL DEFAULT 15,
        dias_semana TEXT NOT NULL DEFAULT '1,2,3,4,5',
        hora_almuerzo_inicio TEXT,
        hora_almuerzo_fin TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE empleados (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empresa_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        tipo_documento TEXT NOT NULL DEFAULT 'CC',
        numero_documento TEXT NOT NULL DEFAULT '',
        es_externo INTEGER NOT NULL DEFAULT 0,
        turno_id INTEGER,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (empresa_id) REFERENCES empresas(id),
        FOREIGN KEY (turno_id) REFERENCES turnos(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE registros (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        empresa_id INTEGER NOT NULL,
        empleado_id INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        fecha_hora TEXT NOT NULL,
        foto_path TEXT NOT NULL,
        observacion TEXT,
        motivo_salida TEXT,
        radicado TEXT,
        turno_id INTEGER,
        FOREIGN KEY (empresa_id) REFERENCES empresas(id),
        FOREIGN KEY (empleado_id) REFERENCES empleados(id),
        FOREIGN KEY (turno_id) REFERENCES turnos(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await _createCapacitacionTables(db);
    await _createEmpleadoTurnosTable(db);
  }

  Future<void> _migrateTurnosSinEmpresa(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.execute('''
      CREATE TABLE turnos_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        hora_entrada TEXT NOT NULL,
        hora_salida TEXT NOT NULL,
        tolerancia_minutos INTEGER NOT NULL DEFAULT 15,
        dias_semana TEXT NOT NULL DEFAULT '1,2,3,4,5',
        hora_almuerzo_inicio TEXT,
        hora_almuerzo_fin TEXT
      )
    ''');
    await db.execute('''
      INSERT INTO turnos_new (
        id, nombre, hora_entrada, hora_salida, tolerancia_minutos,
        dias_semana, hora_almuerzo_inicio, hora_almuerzo_fin
      )
      SELECT
        id, nombre, hora_entrada, hora_salida, tolerancia_minutos,
        dias_semana, hora_almuerzo_inicio, hora_almuerzo_fin
      FROM turnos
    ''');
    await db.execute('DROP TABLE turnos');
    await db.execute('ALTER TABLE turnos_new RENAME TO turnos');
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createEmpleadoTurnosTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS empleado_turnos (
        empleado_id INTEGER NOT NULL,
        turno_id INTEGER NOT NULL,
        PRIMARY KEY (empleado_id, turno_id),
        FOREIGN KEY (empleado_id) REFERENCES empleados(id) ON DELETE CASCADE,
        FOREIGN KEY (turno_id) REFERENCES turnos(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createCapacitacionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS capacitaciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        temas TEXT NOT NULL,
        expositor TEXT NOT NULL,
        fecha TEXT NOT NULL,
        empresa_id INTEGER,
        foto_general_path TEXT,
        activa INTEGER NOT NULL DEFAULT 1,
        resultado TEXT,
        cerrada_en TEXT,
        cierre_automatico INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (empresa_id) REFERENCES empresas(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS asistencia_capacitacion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        capacitacion_id INTEGER NOT NULL,
        empleado_id INTEGER NOT NULL,
        fecha_hora TEXT NOT NULL,
        foto_path TEXT NOT NULL,
        FOREIGN KEY (capacitacion_id) REFERENCES capacitaciones(id),
        FOREIGN KEY (empleado_id) REFERENCES empleados(id),
        UNIQUE(capacitacion_id, empleado_id)
      )
    ''');
  }

  static const _registroSelect = '''
      SELECT r.*,
             e.nombre AS empleado_nombre,
             e.tipo_documento AS empleado_tipo_documento,
             e.numero_documento AS empleado_numero_documento,
             e.es_externo AS empleado_es_externo,
             emp.nombre AS empresa_nombre,
             t.nombre AS turno_nombre
      FROM registros r
      JOIN empleados e ON e.id = r.empleado_id
      JOIN empresas emp ON emp.id = r.empresa_id
      LEFT JOIN turnos t ON t.id = r.turno_id
  ''';

  static const _empleadoSelect = '''
      SELECT e.*,
             (SELECT GROUP_CONCAT(t.nombre, ', ')
              FROM empleado_turnos et
              JOIN turnos t ON t.id = et.turno_id
              WHERE et.empleado_id = e.id) AS turnos_nombre
      FROM empleados e
  ''';

  Future<String?> getConfig(String key) async {
    final db = await database;
    final rows = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> setConfig(String key, String value) async {
    final db = await database;
    await db.insert(
      'config',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Empresa>> getEmpresas({bool soloActivas = false}) async {
    final db = await database;
    final rows = await db.query(
      'empresas',
      where: soloActivas ? 'activa = 1' : null,
      orderBy: 'nombre COLLATE NOCASE ASC',
    );
    return rows.map(Empresa.fromMap).toList();
  }

  Future<Empresa?> getEmpresa(int id) async {
    final db = await database;
    final rows = await db.query('empresas', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Empresa.fromMap(rows.first);
  }

  Future<int> insertEmpresa(Empresa empresa) async {
    final db = await database;
    return db.insert('empresas', empresa.toMap()..remove('id'));
  }

  Future<void> updateEmpresa(Empresa empresa) async {
    final db = await database;
    await db.update(
      'empresas',
      empresa.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [empresa.id],
    );
  }

  Future<void> deleteEmpresa(int id) async {
    final laborales = await countRegistrosLaborales(empresaId: id);
    final capacitaciones = await countAsistenciasCapacitacionEmpresa(id);
    if (laborales > 0 || capacitaciones > 0) {
      final partes = <String>[];
      if (laborales > 0) {
        partes.add('$laborales marcacion(es) laboral(es)');
      }
      if (capacitaciones > 0) {
        partes.add('$capacitaciones asistencia(s) a capacitaciones');
      }
      throw ReferentialIntegrityException(
        'No se puede eliminar la empresa: tiene ${partes.join(' y ')}. '
        'Puede marcarla como inactiva.',
      );
    }

    final db = await database;
    final empleados = await db.query(
      'empleados',
      columns: ['id'],
      where: 'empresa_id = ?',
      whereArgs: [id],
    );
    for (final row in empleados) {
      final empId = row['id'] as int;
      final regsEmpleado = await countRegistrosLaborales(empleadoId: empId);
      final capsEmpleado = await countAsistenciasCapacitacionEmpleado(empId);
      if (regsEmpleado > 0 || capsEmpleado > 0) {
        throw ReferentialIntegrityException(
          'No se puede eliminar la empresa: hay colaboradores con registros historicos. '
          'Reasignelos a otra empresa o marque la empresa como inactiva.',
        );
      }
    }

    final caps = await db.query(
      'capacitaciones',
      columns: ['id'],
      where: 'empresa_id = ?',
      whereArgs: [id],
    );
    for (final row in caps) {
      await deleteCapacitacion(row['id'] as int);
    }
    for (final row in empleados) {
      await _deleteEmpleadoSinRegistros(row['id'] as int);
    }
    await db.delete('empresas', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Turno>> getTurnos() async {
    final db = await database;
    final rows = await db.query(
      'turnos',
      orderBy: 'nombre COLLATE NOCASE ASC',
    );
    return rows.map(Turno.fromMap).toList();
  }

  Future<Turno?> getTurno(int id) async {
    final db = await database;
    final rows = await db.query('turnos', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Turno.fromMap(rows.first);
  }

  Future<int> insertTurno(Turno turno) async {
    final db = await database;
    return db.insert('turnos', turno.toMap()..remove('id'));
  }

  Future<void> updateTurno(Turno turno) async {
    final db = await database;
    await db.update(
      'turnos',
      turno.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [turno.id],
    );
  }

  Future<int> countEmpleadosConTurno(int turnoId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT empleado_id) AS c FROM empleado_turnos WHERE turno_id = ?',
      [turnoId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteTurno(int id) async {
    final marcaciones = await countRegistrosLaborales(turnoId: id);
    if (marcaciones > 0) {
      throw ReferentialIntegrityException(
        'No se puede eliminar el turno: tiene $marcaciones marcacion(es) registrada(s).',
      );
    }

    final db = await database;
    await db.delete('empleado_turnos', where: 'turno_id = ?', whereArgs: [id]);
    await db.update(
      'empleados',
      {'turno_id': null},
      where: 'turno_id = ?',
      whereArgs: [id],
    );
    await db.delete('turnos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<int>> getTurnoIdsForEmpleado(int empleadoId) async {
    final db = await database;
    final rows = await db.query(
      'empleado_turnos',
      columns: ['turno_id'],
      where: 'empleado_id = ?',
      whereArgs: [empleadoId],
      orderBy: 'turno_id ASC',
    );
    return rows.map((r) => r['turno_id'] as int).toList();
  }

  Future<List<Turno>> getTurnosForEmpleado(int empleadoId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT t.*
      FROM empleado_turnos et
      JOIN turnos t ON t.id = et.turno_id
      WHERE et.empleado_id = ?
      ORDER BY t.nombre COLLATE NOCASE ASC
    ''', [empleadoId]);
    return rows.map(Turno.fromMap).toList();
  }

  Future<void> setEmpleadoTurnos(int empleadoId, List<int> turnoIds) async {
    final db = await database;
    await db.delete(
      'empleado_turnos',
      where: 'empleado_id = ?',
      whereArgs: [empleadoId],
    );
    for (final turnoId in turnoIds.toSet()) {
      await db.insert('empleado_turnos', {
        'empleado_id': empleadoId,
        'turno_id': turnoId,
      });
    }
    await db.update(
      'empleados',
      {'turno_id': turnoIds.isEmpty ? null : turnoIds.first},
      where: 'id = ?',
      whereArgs: [empleadoId],
    );
  }

  Future<List<Empleado>> getEmpleados({
    int? empresaId,
    bool soloActivos = false,
    bool? esExterno,
  }) async {
    final db = await database;
    final filters = <String>[];
    final args = <Object>[];

    if (empresaId != null) {
      filters.add('e.empresa_id = ?');
      args.add(empresaId);
    }
    if (soloActivos) {
      filters.add('e.activo = 1');
    }
    if (esExterno != null) {
      filters.add('e.es_externo = ?');
      args.add(esExterno ? 1 : 0);
    }

    final where = filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}';
    final rows = await db.rawQuery('''
      $_empleadoSelect
      $where
      ORDER BY e.nombre COLLATE NOCASE ASC
    ''', args);
    return rows.map(Empleado.fromMap).toList();
  }

  Future<Empleado?> getEmpleado(int id) async {
    final db = await database;
    final rows = await db.rawQuery(
      '$_empleadoSelect WHERE e.id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return Empleado.fromMap(rows.first);
  }

  Future<int> insertEmpleado(Empleado empleado, {List<int>? turnoIds}) async {
    final db = await database;
    final id = await db.insert('empleados', empleado.toMap()..remove('id'));
    if (turnoIds != null && turnoIds.isNotEmpty) {
      await setEmpleadoTurnos(id, turnoIds);
    }
    return id;
  }

  Future<void> updateEmpleado(Empleado empleado, {List<int>? turnoIds}) async {
    final db = await database;
    await db.update(
      'empleados',
      empleado.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [empleado.id],
    );
    if (turnoIds != null) {
      await setEmpleadoTurnos(empleado.id!, turnoIds);
    }
  }

  Future<void> deleteEmpleado(int id) async {
    final laborales = await countRegistrosLaborales(empleadoId: id);
    final capacitaciones = await countAsistenciasCapacitacionEmpleado(id);
    if (laborales > 0 || capacitaciones > 0) {
      final partes = <String>[];
      if (laborales > 0) {
        partes.add('$laborales marcacion(es) laboral(es)');
      }
      if (capacitaciones > 0) {
        partes.add('$capacitaciones asistencia(s) a capacitaciones');
      }
      throw ReferentialIntegrityException(
        'No se puede eliminar: tiene ${partes.join(' y ')}. '
        'Puede desactivarlo en su lugar.',
      );
    }

    final db = await database;
    await db.delete('empleado_turnos', where: 'empleado_id = ?', whereArgs: [id]);
    await db.delete('empleados', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _deleteEmpleadoSinRegistros(int id) async {
    final db = await database;
    await db.delete('empleado_turnos', where: 'empleado_id = ?', whereArgs: [id]);
    await db.delete('empleados', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countRegistrosLaborales({
    int? empleadoId,
    int? empresaId,
    int? turnoId,
  }) async {
    final filters = <String>[];
    final args = <Object>[];

    if (empleadoId != null) {
      filters.add('empleado_id = ?');
      args.add(empleadoId);
    }
    if (empresaId != null) {
      filters.add('empresa_id = ?');
      args.add(empresaId);
    }
    if (turnoId != null) {
      filters.add('turno_id = ?');
      args.add(turnoId);
    }
    if (filters.isEmpty) return 0;

    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM registros WHERE ${filters.join(' AND ')}',
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countAsistenciasCapacitacionEmpleado(int empleadoId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM asistencia_capacitacion WHERE empleado_id = ?',
      [empleadoId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countAsistenciasCapacitacionEmpresa(int empresaId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM asistencia_capacitacion ac
      WHERE EXISTS (
        SELECT 1 FROM empleados e
        WHERE e.id = ac.empleado_id AND e.empresa_id = ?
      )
      OR EXISTS (
        SELECT 1 FROM capacitaciones c
        WHERE c.id = ac.capacitacion_id AND c.empresa_id = ?
      )
    ''', [empresaId, empresaId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> insertRegistro(Registro registro) async {
    final db = await database;
    return db.insert('registros', registro.toMap()..remove('id'));
  }

  Future<Registro?> getUltimoRegistroEmpleado(int empleadoId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      $_registroSelect
      WHERE r.empleado_id = ?
      ORDER BY r.fecha_hora DESC
      LIMIT 1
    ''', [empleadoId]);
    if (rows.isEmpty) return null;
    return Registro.fromMap(rows.first);
  }

  Future<List<Registro>> getRegistros({
    int? empresaId,
    int? empleadoId,
    bool? esExterno,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final db = await database;
    final filters = <String>[];
    final args = <Object>[];

    if (empresaId != null) {
      filters.add('r.empresa_id = ?');
      args.add(empresaId);
    }
    if (empleadoId != null) {
      filters.add('r.empleado_id = ?');
      args.add(empleadoId);
    }
    if (esExterno != null) {
      filters.add('e.es_externo = ?');
      args.add(esExterno ? 1 : 0);
    }
    if (desde != null) {
      filters.add('r.fecha_hora >= ?');
      args.add(desde.toIso8601String());
    }
    if (hasta != null) {
      filters.add('r.fecha_hora <= ?');
      args.add(hasta.toIso8601String());
    }

    final where = filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}';
    final rows = await db.rawQuery('''
      $_registroSelect
      $where
      ORDER BY r.fecha_hora DESC
    ''', args);

    return rows.map(Registro.fromMap).toList();
  }

  static const _capacitacionSelect = '''
      SELECT c.*,
             emp.nombre AS empresa_nombre,
             (SELECT COUNT(*) FROM asistencia_capacitacion ac
              WHERE ac.capacitacion_id = c.id) AS total_asistentes
      FROM capacitaciones c
      LEFT JOIN empresas emp ON emp.id = c.empresa_id
  ''';

  static const _asistenciaCapSelect = '''
      SELECT ac.*,
             e.nombre AS empleado_nombre,
             e.tipo_documento AS empleado_tipo_documento,
             e.numero_documento AS empleado_numero_documento,
             e.es_externo AS empleado_es_externo,
             emp.nombre AS empresa_nombre,
             cap.nombre AS capacitacion_nombre
      FROM asistencia_capacitacion ac
      JOIN empleados e ON e.id = ac.empleado_id
      JOIN empresas emp ON emp.id = e.empresa_id
      JOIN capacitaciones cap ON cap.id = ac.capacitacion_id
  ''';

  Future<List<Capacitacion>> getCapacitaciones({
    bool? soloAbiertas,
    bool? soloHoy,
    int? empresaId,
  }) async {
    final db = await database;
    final filters = <String>[];
    final args = <Object>[];

    if (soloAbiertas == true) {
      filters.add('c.activa = 1');
    }
    if (soloHoy == true) {
      filters.add('c.fecha = ?');
      args.add(Capacitacion.dateKey(DateTime.now()));
    }
    if (empresaId != null) {
      filters.add('(c.empresa_id = ? OR c.empresa_id IS NULL)');
      args.add(empresaId);
    }

    final where = filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}';
    final rows = await db.rawQuery('''
      $_capacitacionSelect
      $where
      ORDER BY c.fecha DESC, c.nombre COLLATE NOCASE ASC
    ''', args);
    return rows.map(Capacitacion.fromMap).toList();
  }

  Future<Capacitacion?> getCapacitacion(int id) async {
    final db = await database;
    final rows = await db.rawQuery(
      '$_capacitacionSelect WHERE c.id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return Capacitacion.fromMap(rows.first);
  }

  Future<int> insertCapacitacion(Capacitacion capacitacion) async {
    final db = await database;
    return db.insert('capacitaciones', capacitacion.toMap()..remove('id'));
  }

  Future<void> updateCapacitacion(Capacitacion capacitacion) async {
    final db = await database;
    await db.update(
      'capacitaciones',
      capacitacion.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [capacitacion.id],
    );
  }

  Future<void> deleteCapacitacion(int id) async {
    final asistencias = await countAsistenciaCapacitacion(id);
    if (asistencias > 0) {
      throw ReferentialIntegrityException(
        'No se puede eliminar la capacitacion: tiene $asistencias asistencia(s) registrada(s).',
      );
    }

    final db = await database;
    await db.delete('capacitaciones', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countAsistenciaCapacitacion(int capacitacionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM asistencia_capacitacion WHERE capacitacion_id = ?',
      [capacitacionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> empleadoYaAsistioCapacitacion(
    int capacitacionId,
    int empleadoId,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM asistencia_capacitacion '
      'WHERE capacitacion_id = ? AND empleado_id = ?',
      [capacitacionId, empleadoId],
    );
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }

  Future<int> insertAsistenciaCapacitacion(
    AsistenciaCapacitacion asistencia,
  ) async {
    final db = await database;
    return db.insert(
      'asistencia_capacitacion',
      asistencia.toMap()..remove('id'),
    );
  }

  Future<List<AsistenciaCapacitacion>> getAsistenciasCapacitacion({
    int? capacitacionId,
    int? empleadoId,
  }) async {
    final db = await database;
    final filters = <String>[];
    final args = <Object>[];

    if (capacitacionId != null) {
      filters.add('ac.capacitacion_id = ?');
      args.add(capacitacionId);
    }
    if (empleadoId != null) {
      filters.add('ac.empleado_id = ?');
      args.add(empleadoId);
    }

    final where = filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}';
    final rows = await db.rawQuery('''
      $_asistenciaCapSelect
      $where
      ORDER BY ac.fecha_hora ASC
    ''', args);
    return rows.map(AsistenciaCapacitacion.fromMap).toList();
  }
}
