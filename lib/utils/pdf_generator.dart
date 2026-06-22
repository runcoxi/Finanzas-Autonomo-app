import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice.dart';
import '../models/settings.dart';
import 'formatters.dart';

class PdfGenerator {
  static Future<void> shareInvoicePdf(Invoice invoice, AppSettings settings) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => _buildPage(invoice, settings, font, bold),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Factura_${invoice.number}.pdf',
    );
  }

  static pw.Widget _buildPage(
    Invoice invoice,
    AppSettings settings,
    pw.Font font,
    pw.Font bold,
  ) {
    final text = pw.TextStyle(font: font, fontSize: 10);
    final boldSm = pw.TextStyle(font: bold, fontSize: 10);
    final title = pw.TextStyle(font: bold, fontSize: 20);
    final header = pw.TextStyle(font: bold, fontSize: 11);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Cabecera
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('FACTURA', style: title),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Nº: ${invoice.number}', style: boldSm),
                pw.Text('Fecha: ${formatDate(invoice.date)}', style: text),
                if (invoice.dueDate != null)
                  pw.Text('Vencimiento: ${formatDate(invoice.dueDate!)}', style: text),
              ],
            ),
          ],
        ),
        pw.Divider(height: 20, color: PdfColors.grey400),

        // Emisor / Cliente
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('EMISOR', style: header),
                  pw.SizedBox(height: 4),
                  pw.Text(settings.ownerName.isNotEmpty ? settings.ownerName : 'Tu Nombre', style: boldSm),
                  pw.Text('NIF: ${settings.ownerNif.isNotEmpty ? settings.ownerNif : 'XXXXXXXXX'}', style: text),
                  pw.Text(settings.ownerAddress.isNotEmpty ? settings.ownerAddress : 'Tu Dirección', style: text),
                  if (settings.ownerEmail.isNotEmpty) pw.Text(settings.ownerEmail, style: text),
                  if (settings.ownerPhone.isNotEmpty) pw.Text(settings.ownerPhone, style: text),
                ],
              ),
            ),
            pw.SizedBox(width: 40),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CLIENTE', style: header),
                  pw.SizedBox(height: 4),
                  pw.Text(invoice.clientName, style: boldSm),
                  pw.Text('NIF: ${invoice.clientNif}', style: text),
                  pw.Text(invoice.clientAddress, style: text),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        // Tabla de líneas
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('Descripción', boldSm),
                _cell('Cant.', boldSm, center: true),
                _cell('Precio', boldSm, right: true),
                _cell('IVA', boldSm, center: true),
                _cell('Total', boldSm, right: true),
              ],
            ),
            ...invoice.items.map(
              (item) => pw.TableRow(children: [
                _cell(item.description, text),
                _cell(item.quantity % 1 == 0
                    ? item.quantity.toInt().toString()
                    : item.quantity.toStringAsFixed(2), text, center: true),
                _cell(formatCurrency(item.unitPrice), text, right: true),
                _cell('${item.vatRate.toInt()}%', text, center: true),
                _cell(formatCurrency(item.total), text, right: true),
              ]),
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        // Totales
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 240,
              child: pw.Column(children: [
                _totalRow('Base imponible:', formatCurrency(invoice.baseAmount), text, boldSm),
                _totalRow('IVA:', formatCurrency(invoice.totalVat), text, boldSm),
                if (invoice.irpfRate > 0)
                  _totalRow(
                    'IRPF (-${invoice.irpfRate.toInt()}%):',
                    '- ${formatCurrency(invoice.irpfAmount)}',
                    text, boldSm,
                  ),
                pw.Divider(color: PdfColors.grey400),
                _totalRow(
                  'TOTAL:',
                  formatCurrency(invoice.total),
                  pw.TextStyle(font: bold, fontSize: 12),
                  pw.TextStyle(font: bold, fontSize: 12),
                ),
              ]),
            ),
          ],
        ),
        pw.SizedBox(height: 40),

        // Estado
        if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
          pw.Text('Notas:', style: boldSm),
          pw.Text(invoice.notes!, style: text),
          pw.SizedBox(height: 20),
        ],

        pw.Divider(color: PdfColors.grey300),
        pw.Center(
          child: pw.Text(
            'Factura emitida de acuerdo con la normativa fiscal española vigente.',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.TextStyle style,
      {bool center = false, bool right = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: center
            ? pw.Alignment.center
            : right
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
        child: pw.Text(text, style: style),
      ),
    );
  }

  static pw.Widget _totalRow(
      String label, String value, pw.TextStyle lStyle, pw.TextStyle vStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: lStyle),
          pw.Text(value, style: vStyle),
        ],
      ),
    );
  }
}
