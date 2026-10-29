import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Search bar: text on the left; on the right a ✕ (only while typing), the
/// camera (search by photo) and, last, the search magnifier.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.placeholder = 'Rechercher…',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.showClear = true,
    this.onCamera,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// With [readOnly], makes the field a button (e.g. opens the search page).
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;

  /// Shows a ✕ that empties the field while it has text.
  final bool showClear;

  /// Shows a camera button (search by photo).
  final VoidCallback? onCamera;

  void _search(BuildContext context) {
    if (readOnly) {
      onTap?.call();
    } else {
      FocusScope.of(context).unfocus();
      onSubmitted?.call(controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Light grey so the field stands out on the white header.
        color: const Color(0xFFF1F3F7),
        // Pill shape, like the round search button inside.
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      // 3 px around the search circle: it fills the bar's height.
      padding: const EdgeInsets.only(
          left: AppSpacing.lg, right: 3, top: 3, bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onTap: onTap,
              readOnly: readOnly,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: placeholder,
                hintStyle: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          // ✕ appears as soon as something is typed.
          if (showClear && !readOnly)
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : _IconAction(
                      icon: Icons.close,
                      tooltip: 'Effacer',
                      color: AppColors.textSecondary,
                      onPressed: () {
                        controller.clear();
                        onChanged?.call('');
                      },
                    ),
            ),
          if (onCamera != null)
            _IconAction(
              icon: Icons.photo_camera,
              tooltip: 'Rechercher par photo',
              color: const Color(0xFF8A8FA6),
              onPressed: onCamera!,
            ),
          const SizedBox(width: 2),
          // Search button in its own round tile, at the right end.
          Tooltip(
            message: 'Rechercher',
            child: Material(
              color: const Color(0xFFDDE2EC),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _search(context),
                child: const SizedBox.square(
                  dimension: 40,
                  child: Icon(Icons.search,
                      size: 22, color: AppColors.text),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction(
      {required this.icon,
      required this.tooltip,
      required this.color,
      required this.onPressed});
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 36, height: 40),
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20, color: color),
        onPressed: onPressed,
      );
}
