/// Mobile stub for checkout_screen.dart
/// These classes are never navigated to on mobile,
/// but must exist to satisfy the compiler.
import 'package:flutter/material.dart';

class CheckoutScreen extends StatelessWidget {
  final String plan;
  final String period;

  const CheckoutScreen({
    super.key,
    required this.plan,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Checkout is only available on the web app.'),
      ),
    );
  }
}

class CheckoutSuccessScreen extends StatelessWidget {
  const CheckoutSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Subscription activated!'),
      ),
    );
  }
}
