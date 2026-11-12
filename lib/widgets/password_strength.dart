import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils/password.dart';
import '../l10n/strings.dart';

/// Under the password field: a line that grows and changes colour as the
/// password gets stronger, and a checklist that ticks each rule as it is met.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final password = controller.text;
        final (fraction, color, label) = switch (passwordStrength(password)) {
          PasswordStrength.none => (0.0, Colors.grey, ''),
          PasswordStrength.weak => (0.25, AppColors.error, 'Weak'),
          PasswordStrength.fair => (0.5, AppColors.warning, 'Fair'),
          PasswordStrength.good => (0.75, AppColors.primaryBright, 'Good'),
          PasswordStrength.strong => (1.0, AppColors.eco, 'Strong'),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Container(
                      height: 6,
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * fraction,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            if (fraction > 0)
                              BoxShadow(
                                color: color.withValues(alpha: 0.45),
                                blurRadius: 6,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      label.isEmpty ? '' : context.tr(label),
                      key: ValueKey(label),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final rule in passwordRules)
              _RuleRow(label: context.tr(rule.label), met: rule.test(password)),
          ],
        );
      },
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.met});
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met
        ? AppColors.eco
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            ),
            child: Icon(
              met ? Icons.check_circle : Icons.radio_button_unchecked,
              key: ValueKey(met),
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 12.5,
              color: color,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
