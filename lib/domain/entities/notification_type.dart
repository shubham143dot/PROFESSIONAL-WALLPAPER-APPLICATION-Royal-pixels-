enum NotificationType {
  download,
  purchase,
  reward,
  content,
  update,
  system;

  String toJson() => name;
  static NotificationType fromJson(String name) =>
      NotificationType.values.byName(name);
}
