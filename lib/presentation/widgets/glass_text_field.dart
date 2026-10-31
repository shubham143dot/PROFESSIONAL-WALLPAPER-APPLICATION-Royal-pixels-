import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Premier iOS Liquid Glass text field with frosted blur,
/// glowing specular focus ring, and subtle pop scale on focus.
class GlassTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool isDark;
  final TextInputType keyboardType;
  final bool autofocus;
  final int maxLines;
  final TextStyle? textStyle;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffix,
    this.isDark = true,
    this.keyboardType = TextInputType.text,
    this.autofocus = false,
    this.maxLines = 1,
    this.textStyle,
    this.validator,
    this.onChanged,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool highContrast = MediaQuery.of(context).highContrast;
    final textColor = widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final hintColor = widget.isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final activeBorderColor = widget.isDark ? AppColors.goldMid : AppColors.royalIndigo;
    final inactiveBorderColor = highContrast
        ? (widget.isDark ? Colors.white : const Color(0xFF64748B))
        : (widget.isDark ? const Color(0x1FFFFFFF) : Colors.white.withValues(alpha: 0.85));

    final surfaceColor = highContrast
        ? (widget.isDark ? AppColors.bg1 : const Color(0xFFFFFFFF))
        : (widget.isDark ? AppColors.bg2 : Colors.white.withValues(alpha: 0.70));

    Widget fieldContainer = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: surfaceColor,
        border: Border.all(
          color: _isFocused ? activeBorderColor : inactiveBorderColor,
          width: _isFocused ? 1.4 : 0.6,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: activeBorderColor.withValues(alpha: widget.isDark ? 0.35 : 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
                if (!widget.isDark)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 8,
                    offset: const Offset(0, -1),
                  ),
              ]
            : [
                BoxShadow(
                  color: widget.isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : const Color(0xFF64748B).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        maxLines: widget.maxLines,
        style: widget.textStyle ??
            AppTextStyles.bodyLarge.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
        cursorColor: activeBorderColor,
        validator: widget.validator,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.hintText,
          hintStyle: AppTextStyles.bodyLarge.copyWith(color: hintColor),
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  size: 20,
                  color: _isFocused ? activeBorderColor : hintColor,
                )
              : null,
          suffixIcon: widget.suffix,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              widget.labelText!,
              style: AppTextStyles.labelUppercase.copyWith(
                color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
        AnimatedScale(
          scale: _isFocused ? 1.012 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: fieldContainer,
        ),
      ],
    );
  }
}
