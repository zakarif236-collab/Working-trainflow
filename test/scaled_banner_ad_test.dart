import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/scaled_banner_ad.dart';

void main() {
  testWidgets('renders child scaled down by the given scale', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ScaledBannerAd(
              width: 320,
              height: 50,
              scale: 0.5,
              child: ColoredBox(color: Colors.red),
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(ScaledBannerAd));
    expect(size.width, 160);
    expect(size.height, 25);

    final naturalBox = find.descendant(
      of: find.byType(ScaledBannerAd),
      matching: find.byWidgetPredicate(
        (widget) => widget is SizedBox &&
            widget.width == 320 &&
            widget.height == 50,
      ),
    );
    expect(naturalBox, findsOneWidget);
  });
}
