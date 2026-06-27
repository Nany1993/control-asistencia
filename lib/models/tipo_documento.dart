class TipoDocumento {
  const TipoDocumento(this.codigo, this.label);

  final String codigo;
  final String label;

  static const cc = TipoDocumento('CC', 'Cedula de ciudadania');
  static const ce = TipoDocumento('CE', 'Cedula de extranjeria');
  static const ti = TipoDocumento('TI', 'Tarjeta de identidad');
  static const pa = TipoDocumento('PA', 'Pasaporte');
  static const ppt = TipoDocumento('PPT', 'Permiso por proteccion temporal');

  static const List<TipoDocumento> valores = [cc, ce, ti, pa, ppt];

  static TipoDocumento fromCodigo(String codigo) {
    return valores.firstWhere(
      (t) => t.codigo == codigo,
      orElse: () => cc,
    );
  }
}
