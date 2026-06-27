import 'package:flutter/material.dart';

/// Filtra personas por nombre, tipo de documento o numero.
class PersonaSearch {
  PersonaSearch._();

  static String normalize(String value) {
    const accents = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
      'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u',
      'ñ': 'n', 'Ñ': 'n',
    };
    var result = value.toLowerCase().trim();
    accents.forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result.replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool matches({
    required String nombre,
    required String tipoDocumento,
    required String numeroDocumento,
    required String query,
  }) {
    final q = normalize(query);
    if (q.isEmpty) return true;

    final tokens = q.split(' ').where((t) => t.isNotEmpty);
    final haystack = normalize('$nombre $tipoDocumento $numeroDocumento $tipoDocumento$numeroDocumento');

    for (final token in tokens) {
      if (!haystack.contains(token)) return false;
    }
    return true;
  }
}

class PersonaSearchField extends StatelessWidget {
  const PersonaSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Buscar por nombre o documento...',
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                },
              ),
      ),
    );
  }
}
