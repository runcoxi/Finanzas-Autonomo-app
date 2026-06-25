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
  final Uint8List? image;

  const ExtractedTicketData({
    this.concepto,
    this.importeBase,
    this.vatRate,
    this.irpfRate,
    this.proveedor,
    this.numeroFactura,
    this.fecha,
    this.notas,
    this.image,
  });
}

class GeminiService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash-lite:generateContent';

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
      '- irpf_porcentaje: solo puede ser 0, 1, 7, 15, 19 o 21. Si no hay retención, usa 0.\n'
      '- fecha: formato YYYY-MM-DD. null si no aparece.\n'
      '- Usa null para campos que no puedas determinar con certeza.';

  Future<ExtractedTicketData> extractFromImage(
    Uint8List bytes,
    String fileName,
    String apiKey, {
    void Function(String)? onStatus,
  }) async {
    const maxAttempts = 3;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final response = await _post(bytes, fileName, apiKey);

      if (response.statusCode == 200) {
        return _parse(response.body);
      }

      final isRetryable =
          response.statusCode == 429 || response.statusCode == 503;
      if (!isRetryable || attempt == maxAttempts - 1) {
        throw Exception(_errorMessage(response));
      }

      final delaySecs = response.statusCode == 429
          ? _parseRetryDelay(response.body)
          : 6;
      onStatus?.call('Servidor ocupado. Reintentando en ${delaySecs}s…');
      await Future.delayed(Duration(seconds: delaySecs));
      onStatus?.call('Analizando con IA…');
    }

    throw Exception('Error inesperado');
  }

  Future<http.Response> _post(
      Uint8List bytes, String fileName, String apiKey) {
    final base64Image = base64Encode(bytes);
    return http
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
  }

  ExtractedTicketData _parse(String responseBody) {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    final parts =
        ((body['candidates'] as List).first)['content']['parts'] as List;
    final text = parts.first['text'] as String;

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

  static String _errorMessage(http.Response response) {
    try {
      final err = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = (err['error'] as Map?)?['message'] as String?;
      return 'HTTP ${response.statusCode}: ${msg ?? response.body}';
    } catch (_) {
      return 'HTTP ${response.statusCode}: ${response.body}';
    }
  }

  // Extracts the retry delay in seconds from a 429 response body.
  // The API returns: "Please retry in 4.02630138s."
  static int _parseRetryDelay(String body) {
    try {
      final match = RegExp(r'retry in (\d+(?:\.\d+)?)s').firstMatch(body);
      if (match != null) {
        return (double.parse(match.group(1)!) + 1).ceil();
      }
    } catch (_) {}
    return 65;
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
