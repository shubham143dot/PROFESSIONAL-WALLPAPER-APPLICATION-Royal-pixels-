class IapConstants {
  // One-time Diamond Packs (Managed / Consumables)
  static const String pack300 = 'pack_300';
  static const String pack800 = 'pack_800';
  static const String pack2000 = 'pack_2000';
  static const String pack3500 = 'pack_3500';
  static const String pack7000 = 'pack_7000';
  
  // Lifetime (Managed / Non-consumable)
  static const String lifetime = 'lifetime';

  // Memberships (Subscriptions)
  static const String monthly = 'monthly';
  static const String semiAnnual = 'semi_annual';
  static const String annual = 'annual';

  static const List<String> allIds = [
    pack300, pack800, pack2000, pack3500, pack7000,
    lifetime, monthly, semiAnnual, annual
  ];
}
