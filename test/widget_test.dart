import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PdfReaderApp());
    expect(find.text('Lector PDF'), findsWidgets);
  });
}
