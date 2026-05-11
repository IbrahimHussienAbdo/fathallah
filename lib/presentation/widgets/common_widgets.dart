import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

// ── Number formatting ─────────────────────────────────

final _numFmt  = NumberFormat('#,##0.##',  'en_US');
final _currFmt = NumberFormat('#,##0.00', 'en_US');

/// Formats a number with thousand-separators (e.g. 1,659,087.5).
String fmtNum(double v) => _numFmt.format(v);

/// Formats a currency value to 2 decimal places (e.g. 1,659,087.27).
String fmtCurr(double v) => _currFmt.format(v);

// ── Gradient AppBar ───────────────────────────────────

/// An [AppBar] with the brand primary gradient background.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: AppBar(
        title: Text(title),
        actions: actions,
        backgroundColor: Colors.transparent,
        bottom: bottom,
      ),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────

/// Displays a single key performance indicator with icon, label and value.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final IconData icon;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Upload Card ───────────────────────────────────────

/// Tappable card used for uploading a specific file type.
class UploadCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String hint;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool disabled;

  const UploadCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.icon,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.25)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(hint,
                          style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.cloud_upload_outlined, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────

/// Bold section label with coloured left-border accent.
class SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const SectionLabel(this.text, {super.key, this.color = AppTheme.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary)),
    );
  }
}

// ── Empty State ───────────────────────────────────────

/// Full-screen placeholder when a list is empty.
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    height: 1.5)),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Status Banner ─────────────────────────────────────

/// Inline status/feedback message strip.
class StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const StatusBanner(
      {super.key, required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.danger : AppTheme.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color,
              size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

// ── Profit Progress Row ───────────────────────────────

/// Visual cost vs. revenue bar used in the profit report.
class ProfitProgressRow extends StatelessWidget {
  final double cost;
  final double revenue;

  const ProfitProgressRow(
      {super.key, required this.cost, required this.revenue});

  @override
  Widget build(BuildContext context) {
    final ratio = revenue > 0 ? (cost / revenue).clamp(0.0, 1.0) : 1.0;
    final isProfit = revenue >= cost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor:
                isProfit ? Colors.green.shade100 : Colors.red.shade100,
            valueColor: AlwaysStoppedAnimation(
                isProfit ? Colors.orange.shade400 : Colors.red.shade400),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cost ${(ratio * 100).toStringAsFixed(0)}% of Revenue',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
