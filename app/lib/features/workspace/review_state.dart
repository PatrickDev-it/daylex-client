import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Turn shown in the Review tab; null means the latest one.
final reviewTurnProvider = NotifierProvider<ReviewTurnNotifier, String?>(
  ReviewTurnNotifier.new,
);

class ReviewTurnNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? turnId) => state = turnId;
}
