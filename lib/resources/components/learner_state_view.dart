import 'package:flutter/material.dart';

enum LearnerStateKind { loading, empty, error, locked }

/// A consistent, learner-friendly treatment for non-content states.
///
/// It deliberately avoids exposing backend exceptions and preserves a clear
/// next action, so a momentary sync issue never looks like a dead end.
class LearnerStateView extends StatelessWidget {
  final LearnerStateKind kind;
  final String eyebrow;
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const LearnerStateView({
    super.key,
    required this.kind,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  const LearnerStateView.loading({
    super.key,
    this.eyebrow = 'PERSONALIZING',
    required this.title,
    required this.message,
    this.icon = Icons.auto_awesome_rounded,
  }) : kind = LearnerStateKind.loading,
       actionLabel = null,
       onAction = null,
       secondaryLabel = null,
       onSecondary = null;

  const LearnerStateView.error({
    super.key,
    this.eyebrow = 'SYNC PAUSED',
    required this.title,
    required this.message,
    this.icon = Icons.cloud_off_rounded,
    this.actionLabel = 'Try again',
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  }) : kind = LearnerStateKind.error;

  const LearnerStateView.empty({
    super.key,
    this.eyebrow = 'YOUR NEXT MILESTONE',
    required this.title,
    required this.message,
    this.icon = Icons.explore_rounded,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  }) : kind = LearnerStateKind.empty;

  Color get _accent => switch (kind) {
    LearnerStateKind.error => const Color(0xFFFB7185),
    LearnerStateKind.locked => const Color(0xFFF59E0B),
    LearnerStateKind.loading => const Color(0xFF22D3EE),
    LearnerStateKind.empty => const Color(0xFF8B5CF6),
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF101C2E).withOpacity(.98),
                _accent.withOpacity(.10),
                const Color(0xFF101C2E).withOpacity(.98),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _accent.withOpacity(.24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.26),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
              BoxShadow(color: _accent.withOpacity(.08), blurRadius: 34),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_accent, const Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(.24),
                      blurRadius: 22,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: kind == LearnerStateKind.loading
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.6,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 31),
              ),
              const SizedBox(height: 18),
              Text(
                eyebrow,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.25,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2563EB),
                          Color(0xFF06B6D4),
                          Color(0xFF7C3AED),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: FilledButton.icon(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                      label: Text(actionLabel!),
                    ),
                  ),
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 7),
                TextButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
