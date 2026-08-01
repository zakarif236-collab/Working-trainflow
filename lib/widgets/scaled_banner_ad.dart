import 'package:flutter/material.dart';

class ScaledBannerAd extends StatelessWidget {
  const ScaledBannerAd({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    this.scale = 0.5,
  });

  final double width;
  final double height;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width * scale,
      height: height * scale,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    );
  }
}
