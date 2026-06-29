import 'package:control_asistencia/utils/texto_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextoDisplay', () {
    test('mayus normaliza y recorta', () {
      expect(TextoDisplay.mayus('  hola  '), 'HOLA');
      expect(TextoDisplay.mayus(null), '');
      expect(TextoDisplay.mayus(''), '');
    });

    test('mayusOpcional devuelve null si vacio', () {
      expect(TextoDisplay.mayusOpcional(null), isNull);
      expect(TextoDisplay.mayusOpcional('  '), isNull);
      expect(TextoDisplay.mayusOpcional('hola'), 'HOLA');
    });

    test('tituloPalabras formatea cada palabra', () {
      expect(
        TextoDisplay.tituloPalabras('seguridad industrial'),
        'Seguridad Industrial',
      );
      expect(TextoDisplay.tituloPalabras(null), '');
      expect(TextoDisplay.tituloPalabras('  '), '');
    });
  });
}
