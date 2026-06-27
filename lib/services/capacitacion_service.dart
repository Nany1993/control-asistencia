import '../database/db_helper.dart';
import '../models/capacitacion.dart';

class CapacitacionService {
  CapacitacionService._();
  static final CapacitacionService instance = CapacitacionService._();

  static DateTime inicioDia(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Cierra capacitaciones cuya fecha ya paso y define ejecutada / no ejecutada.
  Future<void> cerrarCapacitacionesVencidas() async {
    final abiertas = await DbHelper.instance.getCapacitaciones(soloAbiertas: true);
    final hoy = inicioDia(DateTime.now());

    for (final cap in abiertas) {
      if (cap.fechaDia.isBefore(hoy)) {
        await cerrarCapacitacion(cap.id!, automatico: true);
      }
    }
  }

  Future<void> cerrarCapacitacion(int id, {bool automatico = false}) async {
    final cap = await DbHelper.instance.getCapacitacion(id);
    if (cap == null || !cap.activa) return;

    final total = await DbHelper.instance.countAsistenciaCapacitacion(id);
    final resultado = total > 0
        ? ResultadoCapacitacion.ejecutada.value
        : ResultadoCapacitacion.noEjecutada.value;

    await DbHelper.instance.updateCapacitacion(
      cap.copyWith(
        activa: false,
        resultado: resultado,
        cerradaEn: DateTime.now(),
        cierreAutomatico: automatico,
      ),
    );
  }

  bool puedeMarcarHoy(Capacitacion cap) {
    if (!cap.activa) return false;
    final hoy = inicioDia(DateTime.now());
    return cap.fechaDia == hoy;
  }
}
