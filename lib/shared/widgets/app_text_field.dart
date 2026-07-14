// lib/shared/widgets/app_text_field.dart
//
// Premium Material 3 styled text field with two visual modes:
//   • Standard (default) — clean surface with subtle border, animated focus ring.
//   • Glass (isGlass: true) — translucent white overlay for gradient backgrounds.
//
// Features:
//   • Floating label OR fixed label (auto-floats on focus / when filled).
//   • Animated focus state (border color + subtle fill shift).
//   • Built-in password visibility toggle when obscureText = true.
//   • Helper / error text support.
//   • Consistent 14px corner radius (Material 3 medium shape).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final String? initialValue;
  final bool isGlass;
  final EdgeInsetsGeometry? contentPadding;
  final bool enabled;
  final String? helperText;
  final String? errorText;
  final TextDirection? textDirection;
  final bool useFloatingLabel;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.initialValue,
    this.isGlass = false,
    this.contentPadding,
    this.enabled = true,
    this.helperText,
    this.errorText,
    this.textDirection,
    this.useFloatingLabel = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  Widget? get _suffixWidget {
    if (widget.obscureText) {
      return IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            _obscured
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            key: ValueKey(_obscured),
            size: 20,
            color: widget.isGlass
                ? Colors.white54
                : (_isFocused ? AppColors.accent : AppColors.textTertiaryLight),
          ),
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
        splashRadius: 18,
        tooltip: _obscured ? 'Show password' : 'Hide password',
      );
    }
    return widget.suffixIcon;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGlass) {
      return _buildGlassField(context);
    }
    return _buildStandardField(context);
  }

  Widget _buildGlassField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 7),
        ],
        Focus(
          onFocusChange: (v) => setState(() => _isFocused = v),
          child: TextFormField(
            controller: widget.controller,
            initialValue:
                widget.controller == null ? widget.initialValue : null,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            obscureText: _obscured,
            readOnly: widget.readOnly,
            enabled: widget.enabled,
            onTap: widget.onTap,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            focusNode: widget.focusNode,
            textCapitalization: widget.textCapitalization,
            autofocus: widget.autofocus,
            textDirection: widget.textDirection,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: widget.errorText,
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: widget.prefixIcon,
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
              suffixIcon: _suffixWidget,
              contentPadding: widget.contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: _isFocused
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.18)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.18)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFFFF6B6B), width: 1.6),
              ),
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 14,
              ),
              errorStyle: const TextStyle(
                color: Color(0xFFFF8A8A),
                fontSize: 12,
                height: 1.4,
              ),
              counterText: '',
            ),
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helperText!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.55),
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStandardField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              letterSpacing: 0.1,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 7),
        ],
        Focus(
          onFocusChange: (v) => setState(() => _isFocused = v),
          child: TextFormField(
            controller: widget.controller,
            initialValue:
                widget.controller == null ? widget.initialValue : null,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            obscureText: _obscured,
            readOnly: widget.readOnly,
            enabled: widget.enabled,
            onTap: widget.onTap,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            focusNode: widget.focusNode,
            textCapitalization: widget.textCapitalization,
            autofocus: widget.autofocus,
            textDirection: widget.textDirection,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: widget.errorText,
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: widget.prefixIcon,
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
              suffixIcon: _suffixWidget,
              contentPadding: widget.contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              counterText: '',
            ),
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helperText!,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
