import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import 'pressable.dart';
import 'sheets.dart';

/// Label above a control, plus optional hint and error (web `ui-field`).
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.error,
    this.required = false,
  });

  final String label;
  final Widget child;
  final String? hint;
  final String? error;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text.rich(
            TextSpan(
              text: label,
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.rose500),
                  ),
              ],
            ),
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.slate600,
              fontSize: 13,
            ),
          ),
        ),
        child,
        AnimatedSize(
          duration: AppMotion.fast,
          curve: AppMotion.ease,
          alignment: Alignment.topLeft,
          child: error != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Text(
                    error!,
                    style: textTheme.labelMedium
                        ?.copyWith(color: AppColors.rose600),
                  ),
                )
              : hint != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Text(
                        hint!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.slate500),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.keyboardType,
    this.validator,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.prefixText,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.required = false,
    this.enabled = true,
    this.obscure = false,
    this.autofocus = false,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final String? Function(String value)? validator;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final String? prefixText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final bool required;
  final bool enabled;
  final bool obscure;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final multiline = widget.maxLines != 1;

    return LabeledField(
      label: widget.label,
      required: widget.required,
      hint: widget.helper,
      child: TextFormField(
        controller: widget.controller,
        initialValue: widget.controller == null ? widget.initialValue : null,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        obscureText: widget.obscure && _hidden,
        keyboardType: widget.keyboardType ??
            (multiline ? TextInputType.multiline : TextInputType.text),
        textInputAction: widget.textInputAction ??
            (multiline ? TextInputAction.newline : TextInputAction.next),
        textCapitalization: widget.textCapitalization,
        maxLength: widget.maxLength,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        minLines: widget.minLines,
        inputFormatters: widget.inputFormatters,
        autofillHints: widget.autofillHints,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: textTheme.bodyLarge,
        validator: widget.validator == null
            ? null
            : (value) => widget.validator!(value ?? ''),
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixText: widget.prefixText,
          prefixStyle: textTheme.bodyLarge?.copyWith(color: AppColors.slate500),
          errorText: widget.errorText,
          counterText: '',
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  onPressed: () => setState(() => _hidden = !_hidden),
                  icon: AnimatedSwitcher(
                    duration: AppMotion.fast,
                    child: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      key: ValueKey(_hidden),
                      size: 21,
                      color: AppColors.slate500,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Digits only (optionally one decimal separator) for quantity and money inputs.
List<TextInputFormatter> numberFormatters({bool decimal = false, bool signed = false}) {
  final pattern = decimal
      ? (signed ? r'^-?\d*\.?\d{0,4}' : r'^\d*\.?\d{0,4}')
      : (signed ? r'^-?\d*' : r'^\d*');
  return [FilteringTextInputFormatter.allow(RegExp(pattern))];
}

TextInputType numberKeyboard({bool decimal = false, bool signed = false}) =>
    TextInputType.numberWithOptions(decimal: decimal, signed: signed);

class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.depth = 0,
  });

  final T value;
  final String label;
  final String? subtitle;
  final int depth;
}

class _PickerResult<T> {
  const _PickerResult(this.value);
  final T? value;
}

/// One-off option picker (no form field); resolves to the chosen value or null if dismissed.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<PickerOption<T>> options,
  T? selected,
  bool searchable = false,
}) async {
  final result = await showAppSheet<_PickerResult<T>>(
    context,
    builder: (_) => _PickerSheet<T>(
      title: title,
      options: options,
      selected: selected,
      nullLabel: null,
      searchable: searchable,
    ),
  );
  return result?.value;
}

/// Field that opens a bottom sheet list (replaces `<select>`).
class PickerField<T> extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.nullLabel,
    this.hint = 'Seleccionar',
    this.searchable = false,
    this.error,
    this.helper,
    this.required = false,
    this.enabled = true,
    this.sheetTitle,
  });

  final String label;
  final T? value;
  final List<PickerOption<T>> options;
  final ValueChanged<T?> onChanged;

  /// When set, the sheet offers a first row that clears the selection.
  final String? nullLabel;
  final String hint;
  final bool searchable;
  final String? error;
  final String? helper;
  final bool required;
  final bool enabled;
  final String? sheetTitle;

  PickerOption<T>? get _selected {
    for (final option in options) {
      if (option.value == value) return option;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final result = await showAppSheet<_PickerResult<T>>(
      context,
      builder: (_) => _PickerSheet<T>(
        title: sheetTitle ?? label,
        options: options,
        selected: value,
        nullLabel: nullLabel,
        searchable: searchable,
      ),
    );
    if (result != null) onChanged(result.value);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = _selected;
    final text = selected?.label ?? (value == null ? nullLabel : null) ?? hint;
    final isPlaceholder = selected == null && (value != null || nullLabel == null);

    return LabeledField(
      label: label,
      required: required,
      error: error,
      hint: helper,
      child: Pressable(
        onTap: enabled ? () => _open(context) : null,
        scale: 0.99,
        child: Container(
          height: 52,
          padding: const EdgeInsets.only(left: 16, right: 12),
          decoration: BoxDecoration(
            color: enabled ? AppColors.slate50 : AppColors.slate100,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: error != null ? AppColors.rose400 : AppColors.lineStrong,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    color: isPlaceholder ? AppColors.slate400 : null,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.nullLabel,
    required this.searchable,
  });

  final String title;
  final List<PickerOption<T>> options;
  final T? selected;
  final String? nullLabel;
  final bool searchable;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? widget.options
        : widget.options
            .where((o) =>
                o.label.toLowerCase().contains(q) ||
                (o.subtitle?.toLowerCase().contains(q) ?? false))
            .toList();
    final textTheme = Theme.of(context).textTheme;
    final height = MediaQuery.sizeOf(context).height;

    Widget row({
      required String label,
      String? subtitle,
      required bool selected,
      required int depth,
      required VoidCallback onTap,
    }) {
      return Pressable(
        onTap: onTap,
        scale: 0.985,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.fromLTRB(14 + depth * 18.0, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand100 : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.bodyLarge?.copyWith(
                        color: selected ? AppColors.brand800 : null,
                        fontWeight: depth == 0 ? FontWeight.w700 : null,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.slate500),
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 20, color: AppColors.brand600),
            ],
          ),
        ),
      );
    }

    return SheetFrame(
      title: widget.title,
      padBody: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * 0.62),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                child: TextField(
                  autofocus: false,
                  onChanged: (value) => setState(() => _query = value),
                  style: textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Buscar',
                    prefixIcon: Icon(Icons.search_rounded, size: 21),
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                children: [
                  if (widget.nullLabel != null && q.isEmpty)
                    row(
                      label: widget.nullLabel!,
                      selected: widget.selected == null,
                      depth: 0,
                      onTap: () =>
                          Navigator.of(context).pop(_PickerResult<T>(null)),
                    ),
                  for (final option in visible)
                    row(
                      label: option.label,
                      subtitle: option.subtitle,
                      selected: option.value == widget.selected,
                      depth: option.depth,
                      onTap: () => Navigator.of(context)
                          .pop(_PickerResult<T>(option.value)),
                    ),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Sin resultados',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: AppColors.slate500),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date input backed by the platform date picker. Value is `YYYY-MM-DD`.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.hint = 'Seleccionar fecha',
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? error;
  final String hint;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pick(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final current = value == null ? null : DateTime.tryParse(value!);
    final picked = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: current ?? now,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? DateTime(now.year + 5),
      locale: const Locale('es', 'PE'),
    );
    if (picked != null) onChanged(toIsoDay(picked));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LabeledField(
      label: label,
      error: error,
      child: Pressable(
        onTap: () => _pick(context),
        scale: 0.99,
        child: Container(
          height: 52,
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: error != null ? AppColors.rose400 : AppColors.lineStrong,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value == null ? hint : formatDate(value),
                  style: textTheme.bodyLarge?.copyWith(
                    color: value == null ? AppColors.slate400 : null,
                  ),
                ),
              ),
              if (value != null)
                IconButton(
                  tooltip: 'Quitar fecha',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close_rounded,
                      size: 19, color: AppColors.slate400),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.calendar_today_outlined,
                      size: 19, color: AppColors.slate400),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equal-width segmented control with a sliding highlight (like the web nav pill).
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.toneOf,
  });

  final List<(T value, String label)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color Function(T value)? toneOf;

  @override
  Widget build(BuildContext context) {
    final index = options.indexWhere((o) => o.$1 == value).clamp(0, options.length - 1);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / options.length;
          final highlight =
              toneOf?.call(options[index].$1) ?? AppColors.brand600;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 450),
                curve: AppMotion.ease,
                left: width * index,
                width: width,
                top: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: AppMotion.normal,
                  decoration: BoxDecoration(
                    color: highlight,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26101A38),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onChanged(option.$1);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: AppMotion.fast,
                            style: textTheme.labelLarge!.copyWith(
                              color: option.$1 == value
                                  ? Colors.white
                                  : AppColors.slate600,
                            ),
                            child: Text(option.$2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pill search box with a debounced change callback (web `ui-search-input`).
class SearchPill extends StatefulWidget {
  const SearchPill({
    super.key,
    required this.onChanged,
    this.initialValue = '',
    this.hint = 'Buscar',
    this.debounce = const Duration(milliseconds: 350),
    this.autofocus = false,
  });

  final ValueChanged<String> onChanged;
  final String initialValue;
  final String hint;
  final Duration debounce;
  final bool autofocus;

  @override
  State<SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<SearchPill> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  Timer? _timer;
  late String _lastEmitted = widget.initialValue;

  @override
  void didUpdateWidget(SearchPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only an external change (filters cleared, deep link) overwrites what the user typed.
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _lastEmitted) {
      _lastEmitted = widget.initialValue;
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _emit(String value) {
    _lastEmitted = value.trim();
    widget.onChanged(_lastEmitted);
  }

  void _changed(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => _emit(value));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D101A38),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: _changed,
        onSubmitted: (value) {
          _timer?.cancel();
          _emit(value);
        },
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: widget.hint,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 22, color: AppColors.slate400),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          suffixIcon: AnimatedSwitcher(
            duration: AppMotion.fast,
            child: _controller.text.isEmpty
                ? const SizedBox(key: ValueKey('empty'), width: 8)
                : IconButton(
                    key: const ValueKey('clear'),
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(Icons.close_rounded,
                        size: 19, color: AppColors.slate400),
                    onPressed: () {
                      _controller.clear();
                      _timer?.cancel();
                      _emit('');
                      setState(() {});
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// Selectable / removable pill used for quick filters and active-filter chips.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onDeleted,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fg = selected ? Colors.white : AppColors.slate700;
    return Pressable(
      onTap: onTap ?? onDeleted,
      haptic: true,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.ease,
        height: 36,
        padding: EdgeInsets.only(left: 14, right: onDeleted != null ? 8 : 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand600 : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.brand600 : AppColors.lineStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label, style: textTheme.labelMedium?.copyWith(color: fg)),
            if (onDeleted != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, size: 16, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

class SwitchTile extends StatelessWidget {
  const SwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.lineStrong),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.bodyLarge),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.slate500),
                    ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
