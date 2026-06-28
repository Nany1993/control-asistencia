/// Formato visual: toda la informacion en mayusculas.
class TextoDisplay {
  TextoDisplay._();

  static String mayus(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.toUpperCase();
  }

  static String? mayusOpcional(String? value) {
    if (value == null) return null;
    final result = mayus(value);
    return result.isEmpty ? null : result;
  }

  /// Primera letra de cada palabra en mayuscula (para reportes PDF).
  static String tituloPalabras(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }
}

extension TextoDisplayExt on String {
  String get enMayusculas => TextoDisplay.mayus(this);
}
