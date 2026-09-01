import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tk_office/utils/file_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Document Router & File Category Tests', () {
    test('Detect Document Categories correctly for all office formats', () {
      expect(FileUtils.getCategory('report.docx'), DocumentCategory.document);
      expect(FileUtils.getCategory('notes.txt'), DocumentCategory.document);
      expect(FileUtils.getCategory('document.rtf'), DocumentCategory.document);
      expect(FileUtils.getCategory('document.odt'), DocumentCategory.document);

      expect(FileUtils.getCategory('budget.xlsx'), DocumentCategory.spreadsheet);
      expect(FileUtils.getCategory('data.csv'), DocumentCategory.spreadsheet);
      expect(FileUtils.getCategory('sheet.ods'), DocumentCategory.spreadsheet);

      expect(FileUtils.getCategory('pitch.pptx'), DocumentCategory.presentation);
      expect(FileUtils.getCategory('slides.odp'), DocumentCategory.presentation);

      expect(FileUtils.getCategory('assignment.pdf'), DocumentCategory.pdf);

      expect(FileUtils.getCategory('photo.jpg'), DocumentCategory.other);
      expect(FileUtils.getCategory('image.png'), DocumentCategory.other);
    });

    test('Onboarding state persistence in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getBool('setupCompleted'), isNull);

      await prefs.setBool('setupCompleted', true);
      await prefs.setBool('fileAccessConfigured', true);
      await prefs.setString('defaultFolder', 'Documents/TK Office');

      expect(prefs.getBool('setupCompleted'), isTrue);
      expect(prefs.getBool('fileAccessConfigured'), isTrue);
      expect(prefs.getString('defaultFolder'), 'Documents/TK Office');
    });
  });
}
