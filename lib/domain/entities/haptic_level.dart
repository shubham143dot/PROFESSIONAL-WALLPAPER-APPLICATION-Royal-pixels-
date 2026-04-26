enum HapticLevel {
  off('Off', 'Completely disable haptic feedback'),
  light('Light', 'Subtle, gentle sensations'),
  medium('Medium', 'A balanced, crisp response'),
  strong('Strong', 'Maximum feedback for every interaction');

  final String label;
  final String description;
  const HapticLevel(this.label, this.description);

  static HapticLevel fromString(String? value) {
    return HapticLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HapticLevel.medium,
    );
  }
}
