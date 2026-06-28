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
}

extension TextoDisplayExt on String {
  String get enMayusculas => TextoDisplay.mayus(this);
}
