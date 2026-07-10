import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_browser/main.dart';

void main() {
  testWidgets('renders the native Markdown browser shell', (tester) async {
    await tester.pumpWidget(
      const MarkdownBrowserApp(enableNativeWebView: false),
    );

    expect(find.text('Web'), findsOneWidget);
    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('Markdown'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });
}
