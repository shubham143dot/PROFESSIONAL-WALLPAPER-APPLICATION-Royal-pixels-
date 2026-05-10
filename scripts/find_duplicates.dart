import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File(
      r'C:\Users\Subha\.gemini\antigravity\brain\0f98745d-dba2-41dd-9ba9-9399e9019af4\.system_generated\steps\30\content.md');
  final lines = await file.readAsLines();

  int jsonStart = lines.indexWhere((line) => line.startsWith('{'));
  if (jsonStart == -1) return;

  final jsonString = lines.sublist(jsonStart).join('\n');
  final data = json.decode(jsonString);
  var documents = data['documents'] as List<dynamic>;

  Map<String, List<Map<String, String>>> titleToDocs = {};

  for (var doc in documents) {
    String id = doc['name']?.split('/').last ?? '';
    var fields = doc['fields'] ?? {};
    String imageUrl = fields['image_url']?['stringValue'] ?? '';
    String title = fields['title']?['stringValue']?.toLowerCase()?.trim() ?? '';

    if (title.isNotEmpty) {
      titleToDocs.putIfAbsent(title, () => []).add({
        'id': id,
        'url': imageUrl,
      });
    }
  }

  titleToDocs.forEach((title, docs) {
    if (docs.length > 1) {
      stdout.writeln('\nTitle: "$title"');
      for (var d in docs) {
        stdout.writeln('  ID: ${d['id']} -> ${d['url']}');
      }
    }
  });
}
