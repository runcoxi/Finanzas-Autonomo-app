class AppSettings {
  final String ownerName;
  final String ownerNif;
  final String ownerAddress;
  final String ownerPhone;
  final String ownerEmail;
  final String geminiApiKey;

  const AppSettings({
    this.ownerName = '',
    this.ownerNif = '',
    this.ownerAddress = '',
    this.ownerPhone = '',
    this.ownerEmail = '',
    this.geminiApiKey = '',
  });

  Map<String, String> toMap() => {
        'owner_name': ownerName,
        'owner_nif': ownerNif,
        'owner_address': ownerAddress,
        'owner_phone': ownerPhone,
        'owner_email': ownerEmail,
        'gemini_api_key': geminiApiKey,
      };

  factory AppSettings.fromMap(Map<String, String> map) => AppSettings(
        ownerName: map['owner_name'] ?? '',
        ownerNif: map['owner_nif'] ?? '',
        ownerAddress: map['owner_address'] ?? '',
        ownerPhone: map['owner_phone'] ?? '',
        ownerEmail: map['owner_email'] ?? '',
        geminiApiKey: map['gemini_api_key'] ?? '',
      );
}
