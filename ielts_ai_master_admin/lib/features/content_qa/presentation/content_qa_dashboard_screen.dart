import 'package:flutter/material.dart';
import 'package:ielts_ai_master_admin/core/theme/admin_theme.dart';
import 'package:ielts_ai_master_admin/features/content_qa/data/content_qa_service.dart';

class ContentQaDashboardScreen extends StatefulWidget {
  const ContentQaDashboardScreen({super.key});

  @override
  State<ContentQaDashboardScreen> createState() =>
      _ContentQaDashboardScreenState();
}

class _ContentQaDashboardScreenState extends State<ContentQaDashboardScreen> {
  final _service = ContentQaService();
  final _credentialController = TextEditingController();
  final _reasonController = TextEditingController();
  late Future<ContentQaDashboardData> _dashboard;
  Map<String, dynamic>? _credential;
  bool _credentialBusy = false;
  String? _credentialMessage;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _credentialController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _refresh() {
    _dashboard = _service.loadDashboard();
  }

  Future<void> _advance(ContentQaItem item) async {
    final next = item.nextState;
    if (next == null) return;
    String? sourceType;
    String? sourceReference;
    String? copyrightStatus;
    if (next == 'validation_passed' && item.missingProvenance) {
      final provenance = await _requestProvenance();
      if (provenance == null) return;
      sourceType = provenance.$1;
      sourceReference = provenance.$2;
    }
    if (next == 'approved') {
      copyrightStatus = await _requestCopyrightStatus(item.sourceType);
      if (copyrightStatus == null) return;
    }
    try {
      final result = await _service.transition(
        documentPath: item.documentPath,
        targetState: next,
        copyrightStatus: copyrightStatus,
        sourceType: sourceType,
        sourceReference: sourceReference,
      );
      if (!mounted) return;
      final message = result.success
          ? 'Content moved to ${result.state.replaceAll('_', ' ')}.'
          : result.errors.join('\n');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(_refresh);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Future<(String, String)?> _requestProvenance() async {
    var sourceType = 'admin_authored';
    final referenceController = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add source and provenance'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: sourceType,
                  decoration: const InputDecoration(labelText: 'Source type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'admin_authored',
                      child: Text('Admin-authored original'),
                    ),
                    DropdownMenuItem(
                      value: 'licensed',
                      child: Text('Licensed source'),
                    ),
                    DropdownMenuItem(
                      value: 'public_domain',
                      child: Text('Public-domain source'),
                    ),
                    DropdownMenuItem(
                      value: 'ai_generated',
                      child: Text('AI-generated draft'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => sourceType = value ?? sourceType),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Source reference',
                    hintText: 'Internal brief, licence record, URL, or job ID',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final reference = referenceController.text.trim();
                if (reference.isEmpty) return;
                Navigator.pop(dialogContext, (sourceType, reference));
              },
              child: const Text('Validate'),
            ),
          ],
        ),
      ),
    );
    referenceController.dispose();
    return result;
  }

  Future<String?> _requestCopyrightStatus(String sourceType) {
    final aiGenerated = sourceType == 'ai_generated';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Confirm rights review'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, 'original_content_reviewed'),
            child: const Text('Original content reviewed'),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, 'licensed_use_verified'),
            child: const Text('Licensed use verified'),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(dialogContext, 'public_domain_verified'),
            child: const Text('Public-domain status verified'),
          ),
          if (aiGenerated)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(dialogContext, 'ai_generated_reviewed'),
              child: const Text('AI-generated draft reviewed'),
            ),
        ],
      ),
    );
  }

  Future<void> _inspectCredential() async {
    final code = _credentialController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _credentialBusy = true;
      _credentialMessage = null;
    });
    try {
      final result = await _service.inspectCredential(code);
      if (!mounted) return;
      setState(() {
        _credential = result;
        _credentialMessage = result == null ? 'Credential not found.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _credentialMessage = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _credentialBusy = false);
    }
  }

  Future<void> _setCredentialStatus(String status) async {
    final code = _credentialController.text.trim().toUpperCase();
    final reason = _reasonController.text.trim();
    if (status == 'revoked' && reason.length < 5) {
      setState(() => _credentialMessage = 'Enter a clear revocation reason.');
      return;
    }
    setState(() => _credentialBusy = true);
    try {
      await _service.updateCredentialStatus(
        verificationCode: code,
        status: status,
        reason: reason,
      );
      await _inspectCredential();
    } catch (error) {
      if (!mounted) return;
      setState(() => _credentialMessage = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _credentialBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(_refresh);
            await _dashboard;
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Content QA & Credential Safety',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'AI Generated → Validation → Review → Approved → Published',
                style: TextStyle(color: AdminColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 18),
              FutureBuilder<ContentQaDashboardData>(
                future: _dashboard,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _panel(
                      child: Text(
                        _friendlyError(snapshot.error!),
                        style: const TextStyle(color: AdminColors.danger),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _qaContent(snapshot.data!);
                },
              ),
              const SizedBox(height: 20),
              _credentialPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qaContent(ContentQaDashboardData data) {
    const labels = {
      'awaitingReview': 'Awaiting Review',
      'validationFailed': 'Validation Failed',
      'approved': 'Approved',
      'published': 'Published',
      'missingProvenance': 'Missing Source / Provenance',
      'failedGenerationJobs': 'Failed Generation Jobs',
      'legacyContent': 'Legacy Content',
      'certificateAuditReports': 'Certificate Integrity Audits',
    };
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: labels.entries
                  .map(
                    (entry) =>
                        _metric(entry.value, data.counts[entry.key] ?? 0),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'QA queue',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (data.items.isEmpty)
                const Text(
                  'No content is currently waiting in the QA queue.',
                  style: TextStyle(color: AdminColors.textMuted),
                )
              else
                ...data.items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        color: AdminColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${item.documentPath} • ${item.state.replaceAll('_', ' ')}'
                      '${item.missingProvenance ? ' • Missing provenance' : ''}'
                      '${item.validationStatus == 'failed' ? ' • Validation failed' : ''}',
                      style: const TextStyle(
                        color: AdminColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: item.nextState == null
                        ? null
                        : FilledButton(
                            onPressed: () => _advance(item),
                            child: Text(item.nextState!.replaceAll('_', ' ')),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, int value) {
    return _panel(
      child: Row(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: AdminColors.cyan,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AdminColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _credentialPanel() {
    final status = (_credential?['status'] ?? 'unknown').toString();
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Credential lifecycle',
            style: TextStyle(
              color: AdminColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _credentialController,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              hintText: 'IAM-2026-XXXXXXXXXX',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _credentialBusy ? null : _inspectCredential,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Inspect Status'),
          ),
          if (_credential != null) ...[
            const SizedBox(height: 14),
            Text(
              '${_credential!['title'] ?? 'Credential'} • ${status.toUpperCase()}',
              style: const TextStyle(
                color: AdminColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Revocation reason'),
            ),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _credentialBusy || status == 'revoked'
                      ? null
                      : () => _setCredentialStatus('revoked'),
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('Revoke'),
                ),
                FilledButton.icon(
                  onPressed: _credentialBusy || status == 'valid'
                      ? null
                      : () => _setCredentialStatus('valid'),
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Reinstate'),
                ),
              ],
            ),
          ],
          if (_credentialMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _credentialMessage!,
              style: const TextStyle(color: AdminColors.danger),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: child,
    );
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
