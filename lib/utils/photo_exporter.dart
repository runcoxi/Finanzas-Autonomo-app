import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class PhotoExporter {
  /// Exports all receipt photos for [month] as a single ZIP and opens the
  /// share/download sheet. Returns the number of photos included (0 if none).
  static Future<int> exportMonth(DateTime month) async {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final transactions =
        await DatabaseHelper().getTransactions(from: from, to: to);
    final withImages = transactions.where((t) => t.image != null).toList();
    if (withImages.isEmpty) return 0;

    final archive = Archive();
    final usedNames = <String>{};
    for (final t in withImages) {
      final d = t.date;
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      final safeTitle = t.title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final base = safeTitle.isEmpty ? dateStr : '${dateStr}_$safeTitle';

      var name = '$base.jpg';
      var i = 1;
      while (!usedNames.add(name)) {
        name = '${base}_$i.jpg';
        i++;
      }
      archive.addFile(ArchiveFile(name, t.image!.length, t.image!));
    }

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final monthLabel =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final fileName = 'Recibos_$monthLabel.zip';

    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(zipBytes, mimeType: 'application/zip')],
      fileNameOverrides: [fileName],
    ));

    return withImages.length;
  }
}
