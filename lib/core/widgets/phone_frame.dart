import 'package:flutter/material.dart';

/// Web showcase: on wide windows the app sits in a phone-sized frame so it looks exactly like mobile.
/// Narrow windows (real phones in a browser) use the full width.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});
  final Widget child;
  static const size = Size(390, 844);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < 600) return child;
    final h = (mq.size.height - 48).clamp(560.0, size.height);
    return ColoredBox(
      color: const Color(0xFF1C1D22),
      child: Center(
        child: Container(
          width: size.width,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(44),
            border: Border.all(color: const Color(0xFF3A3B42), width: 10),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 16))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: MediaQuery(
              data: mq.copyWith(size: Size(size.width - 20, h - 20), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
