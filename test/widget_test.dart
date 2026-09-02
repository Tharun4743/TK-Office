import 'package:flutter_test/flutter_test.dart';
import 'package:tk_office/core/app_constants.dart';

void main() {
  testWidgets('App Constants and Brand check', (WidgetTester tester) async {
    expect(AppConstants.appName, 'TK Office');
    expect(AppConstants.appTagline, 'Your Documents. Your Device.');
    expect(AppConstants.authorName, 'Tharunkumar K');
    expect(AppConstants.authorEmail, 'tharunkumark42007@gmail.com');
    expect(AppConstants.authorWebsite, 'https://tharunkumark4743.netlify.app/');
  });
}
