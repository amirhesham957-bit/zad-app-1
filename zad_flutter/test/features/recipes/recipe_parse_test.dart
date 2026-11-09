// The chef's full answer reads into its three sections.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/recipes/presentation/recipe_detail_screen.dart';

void main() {
  test('reads ingredients, steps and secrets', () {
    final p = parseRecipeContent('''
المقادير:
• كيلو رز
طريقة التحضير:
1. اغسل الرز على نار هادية عشر دقايق
أسرار الشيف:
- رشة سكر في التحمير
''');
    expect(p.ingredients, <String>['كيلو رز']);
    expect(p.steps, <String>['اغسل الرز على نار هادية عشر دقايق']);
    expect(p.secrets, <String>['رشة سكر في التحمير']);
  });

  test('a long step that says التحضير stays a step', () {
    final p = parseRecipeContent('''
طريقة التحضير:
1. سيبيها ترتاح عشر دقايق بعد التحضير عشان الطعم يتظبط كويس
''');
    expect(p.steps.single, contains('ترتاح'));
  });
}
