import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Screen 1 — Upload Data.
///
/// Lets the user upload a purchases XLSX and a sales CSV file.
/// Shows record counts and upload status feedback.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {

  // ── File picking ──────────────────────────────────────

  /// Displays a non-blocking alert when device free storage is below 50 MB.
  Future<void> _showLowStorageDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.sd_card_alert_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Low Storage'),
          ],
        ),
        content: const Text(
            'Your device has less than 50 MB of free storage. '
            'Please free up space before importing files to prevent data loss.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Opens the platform file picker for the given [type] ('purchases'|'sales'),
  /// then passes the file PATH (not bytes) to the provider so large files
  /// are never fully loaded into RAM at once.
  ///
  /// withData: false — do not buffer the whole file in memory.
  /// withReadStream: false — we use dart:io streaming directly via the path.
  Future<void> _pickFile(BuildContext ctx, String type) async {
    final ext = type == 'sales' ? ['csv', 'xlsx', 'xls'] : ['xlsx', 'xls', 'csv'];
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ext,
      withData: false,      // ← KEY: never loads 400MB into RAM
      withReadStream: false,
    );
    if (result == null || !ctx.mounted) return;
    final file = result.files.first;

    // file.path is guaranteed non-null on mobile when withData: false
    if (file.path == null) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Could not access file path.')),
        );
      }
      return;
    }

    final provider = ctx.read<AppProvider>();
    if (type == 'sales') {
      await provider.uploadSalesFromPath(file.path!, file.name);
    } else {
      await provider.uploadPurchasesFromPath(file.path!, file.name);
    }
  }

  /// Shows a confirmation dialog then clears all data if confirmed.
  Future<void> _confirmClear(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Data'),
        content: const Text(
            'This will permanently delete all purchase and sale records. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(_, true),
              child: const Text('Clear',
                  style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok == true && ctx.mounted) ctx.read<AppProvider>().clearAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Gradient header ───────────────────────────
          _Header(onClear: () => _confirmClear(context)),

          // ── Body ──────────────────────────────────────
          Expanded(
            child: Consumer<AppProvider>(
              builder: (_, p, __) {
                if (p.lowStorageDetected) {
                  // Schedule dialog display for after the build phase.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      p.acknowledgeLowStorage();
                      _showLowStorageDialog();
                    }
                  });
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI row
                      Row(children: [
                        Expanded(
                          child: KpiCard(
                            label: 'Purchase Records',
                            value: p.counts['purchases'].toString(),
                            color: AppTheme.accent,
                            icon: Icons.shopping_cart_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: KpiCard(
                            label: 'Sale Records',
                            value: p.counts['sales'].toString(),
                            color: AppTheme.success,
                            icon: Icons.point_of_sale_outlined,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 28),

                      const SectionLabel('Upload Files'),
                      const SizedBox(height: 4),

                      // Purchases upload card
                      UploadCard(
                        title: 'Upload Purchases',
                        subtitle: 'Expected format: مشتريات_اصناف.xlsx',
                        hint: '.xlsx / .xls',
                        icon: Icons.shopping_cart_outlined,
                        color: AppTheme.accent,
                        disabled: p.isLoading,
                        onTap: () => _pickFile(context, 'purchases'),
                      ),
                      const SizedBox(height: 14),

                      // Sales upload card
                      UploadCard(
                        title: 'Upload Sales',
                        subtitle: 'Expected format: مبيعات_اصناف.csv',
                        hint: '.csv',
                        icon: Icons.point_of_sale_outlined,
                        color: AppTheme.success,
                        disabled: p.isLoading,
                        onTap: () => _pickFile(context, 'sales'),
                      ),
                      const SizedBox(height: 24),

                      // Format reference
                      _FormatReference(),
                      const SizedBox(height: 24),

                      // Loading / status
                      if (p.isLoading)
                        _LoadingIndicator(message: p.statusMessage)
                      else if (p.statusMessage.isNotEmpty)
                        StatusBanner(
                            message: p.statusMessage,
                            isError: p.statusIsError),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onClear;
  const _Header({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
          child: Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data Upload',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Import your purchases & sales files',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                tooltip: 'Clear all data',
                onPressed: onClear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsible reference card showing the expected column formats.
class _FormatReference extends StatefulWidget {
  @override
  State<_FormatReference> createState() => _FormatReferenceState();
}

class _FormatReferenceState extends State<_FormatReference> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header row (always visible)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  const Text('Expected File Formats',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.grey),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            _FormatRow(
              label: 'Purchases XLSX',
              color: AppTheme.accent,
              columns: const [
                'كود الصنف',
                'إسم الصنف',
                'صافى كمية المشتريات',
                'قيمة المشتريات',
              ],
            ),
            const Divider(height: 1, indent: 16),
            _FormatRow(
              label: 'Sales CSV',
              color: AppTheme.success,
              columns: const [
                'كود الصنف',
                'اسم الصنف',
                'اسم الفرع',
                'صافى كمية مبيعات',
                'صافى قيمة مبيعات',
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FormatRow extends StatelessWidget {
  final String label;
  final Color color;
  final List<String> columns;
  const _FormatRow(
      {required this.label,
      required this.color,
      required this.columns});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: columns
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Text(c,
                          style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontFamily: 'monospace')),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Loading indicator ─────────────────────────────────

/// Descriptive loading card shown during file upload and processing.
///
/// Displays a spinner alongside the current [message] so the user
/// knows exactly which processing stage is running.
class _LoadingIndicator extends StatelessWidget {
  final String message;
  const _LoadingIndicator({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: AppTheme.accent.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
