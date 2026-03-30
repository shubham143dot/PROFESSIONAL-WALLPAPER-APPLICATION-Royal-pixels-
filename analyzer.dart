import 'dart:io';

void main() async {
  var result = await Process.run('flutter.bat', ['analyze', '--no-pub']);
  File(
    'analysis.txt',
  ).writeAsStringSync("${result.stdout}\n====\n${result.stderr}");
}
