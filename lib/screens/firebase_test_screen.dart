import 'package:flutter/material.dart';

/// Legacy developer test screen placeholder.
/// Maintained only to avoid breaking any legacy routes; it no longer performs Firebase actions.
class FirebaseTestScreen extends StatelessWidget {
  const FirebaseTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Màn hình thử nghiệm Firebase đã được gỡ khỏi bản phát hành.\n'
          'Nếu cần kiểm thử, hãy dùng nhánh riêng hoặc công cụ debug khác.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
