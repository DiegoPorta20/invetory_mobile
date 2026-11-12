import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/widgets/sheets.dart';
import '../../shared/widgets/states.dart';

/// Create/edit sheet with shared save, delete and error handling.
///
/// [onSave] and [onDelete] throw on failure; an [ApiException] message is shown inline.
/// The sheet pops with `true` after a successful save or delete.
class EntitySheet extends StatefulWidget {
  const EntitySheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.onSave,
    this.onDelete,
    this.deleteTitle = 'Eliminar',
    this.deleteMessage = 'Esta acción no se puede deshacer.',
    this.saveLabel = 'Guardar',
    this.validate,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Future<void> Function() onSave;
  final Future<void> Function()? onDelete;
  final String deleteTitle;
  final String deleteMessage;
  final String saveLabel;

  /// Returns false to block saving (the form shows its own field errors).
  final bool Function()? validate;

  @override
  State<EntitySheet> createState() => _EntitySheetState();
}

class _EntitySheetState extends State<EntitySheet> {
  bool _pending = false;
  String? _error;

  String _messageOf(Object error) {
    if (error is ApiException) {
      if (error.fieldErrors.isNotEmpty && error.code == 'VALIDATION_ERROR') {
        return error.fieldErrors.values.first;
      }
      return error.message;
    }
    return 'Ocurrió un error inesperado.';
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _error = _messageOf(error);
      });
    }
  }

  Future<void> _save() async {
    if (_pending) return;
    if (widget.validate?.call() == false) return;
    await _run(widget.onSave);
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || _pending) return;
    final ok = await confirmAction(
      context,
      title: widget.deleteTitle,
      message: widget.deleteMessage,
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (ok && mounted) await _run(onDelete);
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      footer: Row(
        children: [
          if (widget.onDelete != null) ...[
            Tooltip(
              message: 'Eliminar',
              child: GestureDetector(
                onTap: _pending ? null : _delete,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.rose50,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.rose600, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SheetActions(
              primaryLabel: widget.saveLabel,
              loading: _pending,
              onPrimary: _save,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.child,
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.ease,
            alignment: Alignment.topCenter,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: ErrorBanner(_error!),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Leading icon tile used by simple list rows.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color});

  final IconData icon;
  /// Defaults to the company's brand color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: (color ?? AppColors.brand600).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 22, color: color ?? AppColors.brand600),
    );
  }
}
