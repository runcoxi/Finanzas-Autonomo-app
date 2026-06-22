import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings.dart';
import '../providers/settings_provider.dart';
import '../utils/formatters.dart';
import '../utils/photo_exporter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nifCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _geminiKeyCtrl;
  bool _showApiKey = false;
  DateTime _exportMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>().settings;
    _nameCtrl = TextEditingController(text: s.ownerName);
    _nifCtrl = TextEditingController(text: s.ownerNif);
    _addressCtrl = TextEditingController(text: s.ownerAddress);
    _phoneCtrl = TextEditingController(text: s.ownerPhone);
    _emailCtrl = TextEditingController(text: s.ownerEmail);
    _geminiKeyCtrl = TextEditingController(text: s.geminiApiKey);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nifCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _geminiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<SettingsProvider>().save(AppSettings(
          ownerName: _nameCtrl.text.trim(),
          ownerNif: _nifCtrl.text.trim(),
          ownerAddress: _addressCtrl.text.trim(),
          ownerPhone: _phoneCtrl.text.trim(),
          ownerEmail: _emailCtrl.text.trim(),
          geminiApiKey: _geminiKeyCtrl.text.trim(),
        ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos guardados correctamente')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _changeExportMonth(int delta) async {
    setState(() {
      _exportMonth = DateTime(_exportMonth.year, _exportMonth.month + delta);
    });
  }

  Future<void> _exportPhotos() async {
    setState(() => _exporting = true);
    try {
      final count = await PhotoExporter.exportMonth(_exportMonth);
      if (!mounted) return;
      if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No hay fotos de tickets guardadas ese mes')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Tus datos aparecerán en las facturas PDF que generes.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre completo / Razón social',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nifCtrl,
              decoration: const InputDecoration(
                labelText: 'NIF / NIE',
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección fiscal',
                prefixIcon: Icon(Icons.home),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text('IA — Escáner de tickets',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Introduce tu clave de API de Gemini para escanear tickets y facturas con IA. '
              'Obtenla gratis en aistudio.google.com/apikey',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _geminiKeyCtrl,
              obscureText: !_showApiKey,
              decoration: InputDecoration(
                labelText: 'Clave API Gemini',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(
                      _showApiKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _showApiKey = !_showApiKey),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.photo_library, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text('Exportar fotos de tickets',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Descarga en un .zip todas las fotos de tickets guardadas en un mes, '
              'para no acumular espacio en el teléfono.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: () => _changeExportMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    capitalizeFirst(formatMonthYear(_exportMonth)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeExportMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _exporting ? null : _exportPhotos,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              label: Text(_exporting ? 'Preparando...' : 'Descargar .zip del mes'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Guardar datos'),
            ),
          ],
        ),
      ),
    );
  }
}
