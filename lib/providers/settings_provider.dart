import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = AppSettings(
      ownerName: prefs.getString('owner_name') ?? '',
      ownerNif: prefs.getString('owner_nif') ?? '',
      ownerAddress: prefs.getString('owner_address') ?? '',
      ownerPhone: prefs.getString('owner_phone') ?? '',
      ownerEmail: prefs.getString('owner_email') ?? '',
      ownerBank: prefs.getString('owner_bank') ?? 'BBVA',
      ownerIban: prefs.getString('owner_iban') ?? 'ES76 0182 5297 2302 0172 1273',
      geminiApiKey: prefs.getString('gemini_api_key') ?? '',
    );
    notifyListeners();
  }

  Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('owner_name', s.ownerName);
    await prefs.setString('owner_nif', s.ownerNif);
    await prefs.setString('owner_address', s.ownerAddress);
    await prefs.setString('owner_phone', s.ownerPhone);
    await prefs.setString('owner_email', s.ownerEmail);
    await prefs.setString('owner_bank', s.ownerBank);
    await prefs.setString('owner_iban', s.ownerIban);
    await prefs.setString('gemini_api_key', s.geminiApiKey);
    _settings = s;
    notifyListeners();
  }
}
