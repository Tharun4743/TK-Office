import 'package:flutter_test/flutter_test.dart';
import 'package:tk_office/services/storage_scanner_service/storage_scanner_service.dart';
import 'package:tk_office/utils/file_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Storage Scanner & Extensions Test', () {
    test('Supported extensions include all required office & document formats', () {
      final supported = StorageScannerService.supportedExtensions;

      expect(supported.contains('.pdf'), isTrue);
      expect(supported.contains('.docx'), isTrue);
      expect(supported.contains('.doc'), isTrue);
      expect(supported.contains('.xlsx'), isTrue);
      expect(supported.contains('.xls'), isTrue);
      expect(supported.contains('.csv'), isTrue);
      expect(supported.contains('.pptx'), isTrue);
      expect(supported.contains('.ppt'), isTrue);
      expect(supported.contains('.txt'), isTrue);
      expect(supported.contains('.rtf'), isTrue);
      expect(supported.contains('.odt'), isTrue);
      expect(supported.contains('.ods'), isTrue);
      expect(supported.contains('.odp'), isTrue);
      expect(supported.contains('.jpg'), isTrue);
      expect(supported.contains('.png'), isTrue);
    });

    test('File Category mapping for phone files', () {
      expect(FileUtils.getCategory('/storage/emulated/0/Download/assignment.pdf'), DocumentCategory.pdf);
      expect(FileUtils.getCategory('/storage/emulated/0/Documents/resume.docx'), DocumentCategory.document);
      expect(FileUtils.getCategory('/storage/emulated/0/Download/marks.xlsx'), DocumentCategory.spreadsheet);
      expect(FileUtils.getCategory('/storage/emulated/0/Documents/seminar.pptx'), DocumentCategory.presentation);
    });
  });
}
