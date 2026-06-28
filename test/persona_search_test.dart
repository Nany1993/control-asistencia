import 'package:control_asistencia/utils/persona_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersonaSearch', () {
    test('normaliza tildes y mayusculas', () {
      expect(PersonaSearch.normalize('José María'), 'jose maria');
    });

    test('coincide por nombre o documento', () {
      expect(
        PersonaSearch.matches(
          nombre: 'Ana Perez',
          tipoDocumento: 'CC',
          numeroDocumento: '12345',
          query: 'perez',
        ),
        isTrue,
      );
      expect(
        PersonaSearch.matches(
          nombre: 'Ana Perez',
          tipoDocumento: 'CC',
          numeroDocumento: '12345',
          query: '12345',
        ),
        isTrue,
      );
      expect(
        PersonaSearch.matches(
          nombre: 'Ana Perez',
          tipoDocumento: 'CC',
          numeroDocumento: '12345',
          query: 'luis',
        ),
        isFalse,
      );
    });
  });
}
