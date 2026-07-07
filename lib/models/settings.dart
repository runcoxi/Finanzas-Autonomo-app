class AppSettings {
  final String ownerName;
  final String ownerNif;
  final String ownerAddress;
  final String ownerPhone;
  final String ownerEmail;
  final String ownerBank;
  final String ownerIban;
  final String geminiApiKey;

  const AppSettings({
    this.ownerName = '',
    this.ownerNif = '',
    this.ownerAddress = '',
    this.ownerPhone = '',
    this.ownerEmail = '',
    this.ownerBank = 'BBVA',
    this.ownerIban = 'ES76 0182 5297 2302 0172 1273',
    this.geminiApiKey = '',
  });

  Map<String, String> toMap() => {
        'owner_name': ownerName,
        'owner_nif': ownerNif,
        'owner_address': ownerAddress,
        'owner_phone': ownerPhone,
        'owner_email': ownerEmail,
        'owner_bank': ownerBank,
        'owner_iban': ownerIban,
        'gemini_api_key': geminiApiKey,
      };

  factory AppSettings.fromMap(Map<String, String> map) => AppSettings(
        ownerName: map['owner_name'] ?? '',
        ownerNif: map['owner_nif'] ?? '',
        ownerAddress: map['owner_address'] ?? '',
        ownerPhone: map['owner_phone'] ?? '',
        ownerEmail: map['owner_email'] ?? '',
        ownerBank: map['owner_bank'] ?? '',
        ownerIban: map['owner_iban'] ?? '',
        geminiApiKey: map['gemini_api_key'] ?? '',
      );
}
