import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../data/availability_repository.dart';
import '../domain/slot.dart';
import 'availability_providers.dart';

/// Address search with autocomplete (via the Cloud Functions proxy) that resolves to
/// coordinates, which the travel-time check needs. Quick-pick chips reuse past addresses.
class PickupAutocompleteField extends ConsumerStatefulWidget {
  const PickupAutocompleteField({
    super.key,
    required this.onSelected,
    this.initial,
    this.recent = const [],
    this.onCleared,
  });
  final ValueChanged<PickupLocation> onSelected;
  final VoidCallback? onCleared;
  final PickupLocation? initial;
  final List<PickupLocation> recent;

  @override
  ConsumerState<PickupAutocompleteField> createState() =>
      _PickupAutocompleteFieldState();
}

class _PickupAutocompleteFieldState
    extends ConsumerState<PickupAutocompleteField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial?.address ?? '',
  );
  final _focus = FocusNode();
  Timer? _debounce;
  String _session = PlacesRepository.newSessionToken();
  List<PlaceSuggestion> _suggestions = const [];
  bool _loading = false;
  String? _error;
  PickupLocation? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  void didUpdateWidget(covariant PickupAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.initial;
    if (current != _selected) {
      _selected = current;
      if (current != null) {
        _c.text = current.address;
        _suggestions = const [];
        _error = null;
        _focus.unfocus();
      } else if (oldWidget.initial != null && !_focus.hasFocus) {
        _c.clear();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (_selected != null && text != _selected!.address) {
      setState(() => _selected = null);
      widget.onCleared?.call();
    }
    if (text.trim().length < 3) {
      setState(() {
        _suggestions = const [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(text.trim()),
    );
  }

  Future<void> _search(String text) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(placesRepositoryProvider)
          .autocomplete(text, _session);
      if (!mounted) return;
      setState(() {
        _suggestions = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppFailure.from(e).message;
      });
    }
  }

  Future<void> _pick(PlaceSuggestion s) async {
    setState(() => _loading = true);
    try {
      final loc = await ref
          .read(placesRepositoryProvider)
          .details(s.placeId, _session);
      _session =
          PlacesRepository.newSessionToken(); // a session ends once a place is chosen
      if (!mounted) return;
      _c.text = loc.address;
      _focus.unfocus();
      setState(() {
        _selected = loc;
        _suggestions = const [];
        _loading = false;
      });
      widget.onSelected(loc);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppFailure.from(e).message;
      });
    }
  }

  void _useRecent(PickupLocation l) {
    _c.text = l.address;
    setState(() {
      _selected = l;
      _suggestions = const [];
    });
    widget.onSelected(l);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _c,
          focusNode: _focus,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Pickup address',
            hintText: 'Start typing your street or postcode',
            prefixIcon: const Icon(Icons.place_outlined),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_selected != null
                      ? const Icon(Icons.check_circle, color: AppColors.success)
                      : null),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: t.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                for (final s in _suggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    title: Text(s.description, style: t.bodyMedium),
                    onTap: () => _pick(s),
                  ),
              ],
            ),
          ),
        if (_selected == null && widget.recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Recent pickups', style: t.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in widget.recent)
                ActionChip(
                  avatar: const Icon(Icons.history, size: 16),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(l.address, overflow: TextOverflow.ellipsis),
                  ),
                  onPressed: () => _useRecent(l),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
