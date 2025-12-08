import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedItemsProvider = StateProvider<Set<String>>((ref) => {});
final isSelectionModeProvider = StateProvider<bool>((ref) => false);
