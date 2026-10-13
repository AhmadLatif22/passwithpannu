import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../errors/app_failure.dart';
import 'error_view.dart';
import 'loading_view.dart';

/// One place that renders loading / error / empty / data for any AsyncValue.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.empty,
    this.loading,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        data: (d) => (empty != null && (isEmpty?.call(d) ?? false)) ? empty! : data(d),
        loading: () => loading ?? const SkeletonList(),
        error: (e, _) => ErrorView(message: AppFailure.from(e).message, onRetry: onRetry),
      );
}
