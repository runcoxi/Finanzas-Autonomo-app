import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../utils/formatters.dart';

class ScanTicketScreen extends StatefulWidget {
  const ScanTicketScreen({super.key});

  @override
  State<ScanTicketScreen> createState() => _ScanTicketScreenState();
}

enum _Phase { select, analyzing, results, error }

class _ScanTicketScreenState extends State<ScanTicketScreen> {
  final _picker = ImagePicker();
  final _gemini = GeminiService();

  _Phase _phase = _Phase.select;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _errorMsg;

  final _conceptoCtrl = TextEditingController();
  final _importeCtrl = TextEditingController();
  final _proveedorCtrl = TextEditingController();
  final _facturaCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  DateTime? _fecha;
  double _vatRate = 21;
  double _irpfRate = 0;

  static const _vatRates = [0.0, 4.0, 10.0, 21.0];
  static const _irpfRates = [0.0, 1.0, 7.0, 15.0, 19.0, 21.0];

  @override
  void dispose() {
    _conceptoCtrl.dispose();
    _importeCtrl.dispose();
    _proveedorCtrl.dispose();
    _facturaCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final apiKey = context.read<SettingsProvider>().settings.geminiApiKey;
    if (apiKey.isEmpty) {
      _showNoApiKeyDialog();
      return;
    }

    if (source == ImageSource.camera && !kIsWeb) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permiso de cámara denegado'),
              action: SnackBarAction(
                label: 'Ajustes',
                onPressed: openAppSettings,
              ),
            ),
          );
        }
        return;
      }
    }

    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1200,
      maxHeight: 1600,
    );
    if (xFile == null) return;

    final rawBytes = await xFile.readAsBytes();
    final bytes = _compressForStorage(rawBytes);

    setState(() {
      _imageBytes = bytes;
      _imageName = xFile.name;
      _phase = _Phase.analyzing;
    });

    try {
      final data =
          await _gemini.extractFromImage(_imageBytes!, _imageName!, apiKey);
      _conceptoCtrl.text = data.concepto ?? '';
      _importeCtrl.text =
          data.importeBase != null ? data.importeBase!.toStringAsFixed(2) : '';
      _proveedorCtrl.text = data.proveedor ?? '';
      _facturaCtrl.text = data.numeroFactura ?? '';
      _notasCtrl.text = data.notas ?? '';
      _fecha = data.fecha;
      _vatRate = _closestValue(data.vatRate ?? 21, _vatRates);
      _irpfRate = _closestValue(data.irpfRate ?? 0, _irpfRates);
      setState(() => _phase = _Phase.results);
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _phase = _Phase.error;
      });
    }
  }

  static double _closestValue(double value, List<double> allowed) {
    return allowed
        .reduce((a, b) => (a - value).abs() < (b - value).abs() ? a : b);
  }

  static Uint8List _compressForStorage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized =
        decoded.width > 800 ? img.copyResize(decoded, width: 800) : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 60));
  }

  void _confirm() {
    final amount =
        double.tryParse(_importeCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un importe válido')),
      );
      return;
    }
    Navigator.pop(
      context,
      ExtractedTicketData(
        concepto: _conceptoCtrl.text.trim().isEmpty
            ? null
            : _conceptoCtrl.text.trim(),
        importeBase: amount,
        vatRate: _vatRate,
        irpfRate: _irpfRate,
        proveedor: _proveedorCtrl.text.trim().isEmpty
            ? null
            : _proveedorCtrl.text.trim(),
        numeroFactura: _facturaCtrl.text.trim().isEmpty
            ? null
            : _facturaCtrl.text.trim(),
        fecha: _fecha,
        notas:
            _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        image: _imageBytes,
      ),
    );
  }

  void _showNoApiKeyDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('API Key no configurada'),
        content: const Text(
          'Para usar el escáner de tickets necesitas una clave de API de Gemini.\n\n'
          'Ve a Ajustes → Clave API Gemini y configúrala.\n\n'
          'Obtén tu clave gratuita en:\naistudio.google.com/apikey',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear ticket'),
        actions: [
          if (_phase == _Phase.results)
            TextButton(
              onPressed: _confirm,
              child: const Text('Usar datos',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: switch (_phase) {
        _Phase.select => _SelectPhase(onPick: _pickImage),
        _Phase.analyzing => _AnalyzingPhase(image: _imageBytes!),
        _Phase.results => _ResultsPhase(
            image: _imageBytes!,
            conceptoCtrl: _conceptoCtrl,
            importeCtrl: _importeCtrl,
            proveedorCtrl: _proveedorCtrl,
            facturaCtrl: _facturaCtrl,
            notasCtrl: _notasCtrl,
            fecha: _fecha,
            vatRate: _vatRate,
            irpfRate: _irpfRate,
            vatRates: _vatRates,
            irpfRates: _irpfRates,
            onVatChanged: (v) => setState(() => _vatRate = v),
            onIrpfChanged: (v) => setState(() => _irpfRate = v),
            onDatePick: _pickDate,
            onConfirm: _confirm,
          ),
        _Phase.error => _ErrorPhase(
            message: _errorMsg ?? 'Error desconocido',
            onRetry: () => setState(() => _phase = _Phase.select),
          ),
      },
    );
  }
}

// ── Phase widgets ─────────────────────────────────────────────────────────────

class _SelectPhase extends StatelessWidget {
  final Future<void> Function(ImageSource) onPick;
  const _SelectPhase({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.document_scanner,
                size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Escanea un ticket o factura',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'La IA extraerá automáticamente el importe, IVA, proveedor y más datos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: () => onPick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Abrir cámara'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => onPick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Elegir de galería'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzingPhase extends StatelessWidget {
  final Uint8List image;
  const _AnalyzingPhase({required this.image});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Image.memory(image, fit: BoxFit.contain),
        ),
        const Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analizando con IA...', style: TextStyle(fontSize: 16)),
              SizedBox(height: 4),
              Text(
                'Esto puede tardar unos segundos',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultsPhase extends StatelessWidget {
  final Uint8List image;
  final TextEditingController conceptoCtrl;
  final TextEditingController importeCtrl;
  final TextEditingController proveedorCtrl;
  final TextEditingController facturaCtrl;
  final TextEditingController notasCtrl;
  final DateTime? fecha;
  final double vatRate;
  final double irpfRate;
  final List<double> vatRates;
  final List<double> irpfRates;
  final ValueChanged<double> onVatChanged;
  final ValueChanged<double> onIrpfChanged;
  final VoidCallback onDatePick;
  final VoidCallback onConfirm;

  const _ResultsPhase({
    required this.image,
    required this.conceptoCtrl,
    required this.importeCtrl,
    required this.proveedorCtrl,
    required this.facturaCtrl,
    required this.notasCtrl,
    required this.fecha,
    required this.vatRate,
    required this.irpfRate,
    required this.vatRates,
    required this.irpfRates,
    required this.onVatChanged,
    required this.onIrpfChanged,
    required this.onDatePick,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(image,
              height: 160, width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.green, size: 14),
            const SizedBox(width: 4),
            Text(
              'Datos extraídos con IA — revísalos antes de confirmar',
              style: TextStyle(color: Colors.green[700], fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: conceptoCtrl,
          decoration: const InputDecoration(
            labelText: 'Concepto',
            prefixIcon: Icon(Icons.description),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: proveedorCtrl,
          decoration: const InputDecoration(
            labelText: 'Proveedor / Emisor',
            prefixIcon: Icon(Icons.business),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: importeCtrl,
          decoration: const InputDecoration(
            labelText: 'Importe base (sin IVA)',
            prefixIcon: Icon(Icons.euro),
            suffixText: '€',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<double>(
          value: vatRate,
          decoration: const InputDecoration(labelText: 'IVA'),
          items: vatRates
              .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r == 0 ? 'Sin IVA (0%)' : '${r.toInt()}%'),
                  ))
              .toList(),
          onChanged: (v) => onVatChanged(v ?? 21),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<double>(
          value: irpfRate,
          decoration: const InputDecoration(labelText: 'Retención IRPF'),
          items: irpfRates
              .map((r) => DropdownMenuItem(
                    value: r,
                    child:
                        Text(r == 0 ? 'Sin retención (0%)' : '${r.toInt()}%'),
                  ))
              .toList(),
          onChanged: (v) => onIrpfChanged(v ?? 0),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onDatePick,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha',
              prefixIcon: Icon(Icons.calendar_today),
              suffixIcon: Icon(Icons.edit),
            ),
            child: Text(fecha != null ? formatDate(fecha!) : 'No detectada'),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: facturaCtrl,
          decoration: const InputDecoration(
            labelText: 'Número de factura',
            prefixIcon: Icon(Icons.receipt),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: notasCtrl,
          decoration: const InputDecoration(
            labelText: 'Notas adicionales',
            prefixIcon: Icon(Icons.notes),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onConfirm,
          icon: const Icon(Icons.check),
          label: const Text('Usar estos datos'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ErrorPhase extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPhase({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error al analizar',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar de nuevo'),
            ),
          ],
        ),
      ),
    );
  }
}
