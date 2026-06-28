import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/db_helper.dart';
import '../../database/duplicate_nit_exception.dart';
import '../../database/referential_integrity_exception.dart';
import '../../models/empresa.dart';

class EmpresasScreen extends StatefulWidget {
  const EmpresasScreen({super.key});

  @override
  State<EmpresasScreen> createState() => _EmpresasScreenState();
}

class _EmpresasScreenState extends State<EmpresasScreen> {
  List<Empresa> _empresas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DbHelper.instance.getEmpresas();
    if (mounted) {
      setState(() {
        _empresas = data;
        _loading = false;
      });
    }
  }

  Future<void> _openForm([Empresa? empresa]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EmpresaFormDialog(empresa: empresa),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(Empresa empresa) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar empresa'),
        content: Text(
          'Eliminar "${empresa.nombre}"? '
          'Solo es posible si no tiene marcaciones, asistencias a capacitaciones '
          'ni colaboradores con historial.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await DbHelper.instance.deleteEmpresa(empresa.id!);
      await _load();
    } on ReferentialIntegrityException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Empresas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _empresas.isEmpty
              ? const Center(child: Text('No hay empresas registradas'))
              : ListView.builder(
                  itemCount: _empresas.length,
                  itemBuilder: (context, index) {
                    final empresa = _empresas[index];
                    final subtitulo = [
                      if (empresa.nit.isNotEmpty) 'NIT ${empresa.nit}',
                      empresa.activa ? 'Activa' : 'Inactiva',
                    ].join(' · ');
                    return ListTile(
                      title: Text(empresa.nombre),
                      subtitle: Text(subtitulo),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _openForm(empresa);
                          if (value == 'delete') _delete(empresa);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _EmpresaFormDialog extends StatefulWidget {
  const _EmpresaFormDialog({this.empresa});

  final Empresa? empresa;

  @override
  State<_EmpresaFormDialog> createState() => _EmpresaFormDialogState();
}

class _EmpresaFormDialogState extends State<_EmpresaFormDialog> {
  late final TextEditingController _nombre;
  late final TextEditingController _nit;
  late bool _activa;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.empresa?.nombre ?? '');
    _nit = TextEditingController(text: widget.empresa?.nit ?? '');
    _activa = widget.empresa?.activa ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _nit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nombre = _nombre.text.trim();
    final nit = _nit.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }

    try {
      if (widget.empresa == null) {
        await DbHelper.instance.insertEmpresa(
          Empresa(
            nombre: nombre,
            nit: nit,
            activa: _activa,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await DbHelper.instance.updateEmpresa(
          widget.empresa!.copyWith(nombre: nombre, nit: nit, activa: _activa),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on DuplicateNitException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.empresa == null ? 'Nueva empresa' : 'Editar empresa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nombre,
            decoration: const InputDecoration(
              labelText: 'Nombre *',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nit,
            decoration: const InputDecoration(
              labelText: 'NIT',
              hintText: 'Ej. 900123456-7',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activa'),
            value: _activa,
            onChanged: (v) => setState(() => _activa = v),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
