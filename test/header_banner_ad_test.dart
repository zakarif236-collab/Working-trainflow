import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/header_banner_ad.dart';
import 'package:my_app/widgets/scaled_banner_ad.dart';

void main() {
  testWidgets('renders nothing while no ad is loaded', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: HeaderBannerAd())),
      ),
    );
    await tester.pump();

    expect(find.byType(HeaderBannerAd), findsOneWidget);
    expect(find.byType(ScaledBannerAd), findsNothing);

    final size = tester.getSize(find.byType(HeaderBannerAd));
    expect(size.width, 0);
    expect(size.height, 0);
  });
}
