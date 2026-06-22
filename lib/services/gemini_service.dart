import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ExtractedTicketData {
  final String? concepto;
  final double? importeBase;
  final double? vatRate;
  final double? irpfRate;
  final String? proveedor;
  final String? numeroFactura;
  final DateTime? fecha;
  final String? notas;

  const ExtractedTicketData({
    this.concepto,
    this.importeBase,
    this.vatRate,
    this.irpfRate,
    this.proveedor,
    this.numeroFactura,
    this.fecha,
    this.notas,
  });
}

class GeminiService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash-lite:generateContent';

  // Prompt in Spanish asking for strict JSON output
  static const _prompt =
      'Analiza este ticket o factura y extrae los datos fiscales. '
      'Responde ÚNICAMENTE con un objeto JSON válido, sin texto extra ni bloques markdown.\n\n'
      'Formato exacto:\n'
      '{"concepto":"descripcion del gasto","importe_base":0.00,'
      '"iva_porcentaje":21,"irpf_porcentaje":0,'
      '"proveedor":"nombre empresa","numero_factura":"XXX",'
      '"fecha":"YYYY-MM-DD","notas":"info adicional"}\n\n'
      'Reglas:\n'
      '- importe_base: base imponible sin IVA. Si ves solo el total, calcula la base.\n'
      '- iva_porcentaje: solo puede ser 0, 4, 10 o 21. Elige el valor más cercano.\n'
      '- irpf_porcentaje: solo puede ser 0, 7, 15, 19 o 21. Si no hay retención, usa 0.\n'
      '- fecha: formato YYYY-MM-DD. null si no aparece.\n'
      '- Usa null para campos que no puedas determinar con certeza.';

  Future<ExtractedTicketData> extractFromImage(
    Uint8List bytes,
    String fileName,
    String apiKey,
  ) async {
    final base64Image = base64Encode(bytes);

    final response = await http
        .post(
          Uri.parse('$_endpoint?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': _prompt},
                  {
                    'inline_data': {
                      'mime_type': _mimeType(fileName),
                      'data': base64Image,
                    }
                  }
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'maxOutputTokens': 512,
            },
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      // Throw the raw API response so the UI can show exactly what failed
      String raw;
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        final msg = (err['error'] as Map?)?['message'] as String?;
        raw = 'HTTP ${response.statusCode}: ${msg ?? response.body}';
      } catch (_) {
        raw = 'HTTP ${response.statusCode}: ${response.body}';
      }
      throw Exception(raw);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final parts =
        ((body['candidates'] as List).first)['content']['parts'] as List;
    final text = parts.first['text'] as String;

    // Strip markdown code fences if the model wrapped the JSON
    final cleaned = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final data = jsonDecode(cleaned) as Map<String, dynamic>;
    return ExtractedTicketData(
      concepto: data['concepto'] as String?,
      importeBase: _toDouble(data['importe_base']),
      vatRate: _toDouble(data['iva_porcentaje']),
      irpfRate: _toDouble(data['irpf_porcentaje']),
      proveedor: data['proveedor'] as String?,
      numeroFactura: data['numero_factura'] as String?,
      fecha: _toDate(data['fecha'] as String?),
      notas: data['notas'] as String?,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  static DateTime? _toDate(String? s) {
    if (s == null) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static String _mimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    const types = {
      'png': 'image/png',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'heif': 'image/heif',
    };
    return types[ext] ?? 'image/jpeg';
  }
}
