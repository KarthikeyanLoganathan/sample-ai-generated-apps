import 'dart:io';
// ignore_for_file: avoid_print

void main() {
  final sourceDir = Directory('backend/google-app-script-code');
  final targetDir = Directory('backend-google-app-script-code');

  // Create target directory if it doesn't exist
  if (!targetDir.existsSync()) {
    targetDir.createSync(recursive: true);
    print('Created target directory: ${targetDir.path}');
  }

  // Check if source directory exists
  if (!sourceDir.existsSync()) {
    print('Error: Source directory not found: ${sourceDir.path}');
    exit(1);
  }

  // Copy all .js files
  var copiedCount = 0;
  for (var entity in sourceDir.listSync()) {
    if (entity is File && entity.path.endsWith('.js')) {
      final fileName = entity.uri.pathSegments.last;
      final targetPath = '${targetDir.path}/$fileName';
      entity.copySync(targetPath);
      print('Copied: $fileName');
      copiedCount++;
    }
  }

  print('Successfully copied $copiedCount .js file(s)');
}
