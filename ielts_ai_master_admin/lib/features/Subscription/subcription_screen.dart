import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminSubscriptionManagementScreen extends StatefulWidget {
  const AdminSubscriptionManagementScreen({super.key});

  @override
  State<AdminSubscriptionManagementScreen> createState() =>
      _AdminSubscriptionManagementScreenState();
}

class _AdminSubscriptionManagementScreenState
    extends State<AdminSubscriptionManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _statusFilter = 'pending';
  String _searchQuery = '';
  final Set<String> _processingIds = <String>{};

  Stream<List<SubscriptionRequestModel>> _watchRequests() {
    Query<Map<String, dynamic>> query = _firestore
        .collection('subscription_requests')
        .orderBy('createdAt', descending: true);

    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(SubscriptionRequestModel.fromDocument)
          .where((request) {
            final search = _searchQuery.trim().toLowerCase();

            if (search.isEmpty) return true;

            return request.userName.toLowerCase().contains(search) ||
                request.userEmail.toLowerCase().contains(search) ||
                request.transactionId.toLowerCase().contains(search) ||
                request.requestId.toLowerCase().contains(search);
          })
          .toList(),
    );
  }

  Future<void> _approve(SubscriptionRequestModel request) async {
    if (_processingIds.contains(request.requestId)) return;

    final confirmed = await _showApproveConfirmation(request);

    if (!confirmed || !mounted) return;

    setState(() => _processingIds.add(request.requestId));

    try {
      final requestRef = _firestore
          .collection('subscription_requests')
          .doc(request.requestId);

      final userRef = _firestore.collection('users').doc(request.userId);

      await _firestore.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(requestRef);

        if (!requestSnapshot.exists) {
          throw StateError('Subscription request no longer exists.');
        }

        final currentData = requestSnapshot.data() ?? {};
        final currentStatus = (currentData['status'] ?? 'pending')
            .toString()
            .toLowerCase();

        if (currentStatus == 'approved') {
          throw StateError('This request has already been approved.');
        }

        final now = DateTime.now();
        final existingUserSnapshot = await transaction.get(userRef);
        final existingUser = existingUserSnapshot.data() ?? {};

        final existingExpiry = _date(existingUser['subscriptionExpiresAt']);
        final effectiveStart =
            existingExpiry != null && existingExpiry.isAfter(now)
            ? existingExpiry
            : now;

        final expiry = effectiveStart.add(Duration(days: request.durationDays));

        transaction.set(requestRef, {
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': _auth.currentUser?.uid ?? '',
          'reviewedByEmail': _auth.currentUser?.email ?? '',
          'approvedAt': FieldValue.serverTimestamp(),
          'subscriptionStartsAt': Timestamp.fromDate(effectiveStart),
          'subscriptionExpiresAt': Timestamp.fromDate(expiry),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(userRef, {
          'subscription': {
            'status': 'active',
            'planId': request.planId,
            'planTitle': request.planTitle,
            'amount': request.amount,
            'currency': request.currency,
            'startedAt': Timestamp.fromDate(effectiveStart),
            'expiresAt': Timestamp.fromDate(expiry),
            'requestId': request.requestId,
            'approvedAt': FieldValue.serverTimestamp(),
          },
          'subscriptionStatus': 'active',
          'subscriptionPlan': request.planId,
          'subscriptionPlanTitle': request.planTitle,
          'subscriptionStartAt': Timestamp.fromDate(effectiveStart),
          'subscriptionExpiresAt': Timestamp.fromDate(expiry),
          'subscriptionRequestStatus': 'approved',
          'subscriptionRequestId': request.requestId,
          'isPremium': true,
          'premium': true,
          'premiumPlan': request.planId,
          'premiumStart': Timestamp.fromDate(effectiveStart),
          'premiumExpiresAt': Timestamp.fromDate(expiry),
          'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final auditRef = _firestore.collection('subscription_audit_logs').doc();

        transaction.set(auditRef, {
          'auditId': auditRef.id,
          'action': 'approved',
          'requestId': request.requestId,
          'userId': request.userId,
          'planId': request.planId,
          'amount': request.amount,
          'performedBy': _auth.currentUser?.uid ?? '',
          'performedByEmail': _auth.currentUser?.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      _showMessage(
        '${request.userName} ka ${request.planTitle} approve ho gaya.',
        success: true,
      );
    } catch (error) {
      _showMessage(
        error.toString().replaceFirst('Bad state: ', ''),
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(request.requestId));
      }
    }
  }

  Future<void> _reject(SubscriptionRequestModel request) async {
    if (_processingIds.contains(request.requestId)) return;

    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminSubscriptionColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Reject Payment Request',
          style: TextStyle(
            color: AdminSubscriptionColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: TextField(
          controller: reasonController,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(color: AdminSubscriptionColors.text),
          decoration: const InputDecoration(
            labelText: 'Rejection reason',
            hintText:
                'Example: Transaction ID or screenshot could not be verified.',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = reasonController.text.trim();

              if (value.length < 5) return;

              Navigator.pop(context, value);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AdminSubscriptionColors.red,
            ),
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );

    reasonController.dispose();

    if (reason == null || !mounted) return;

    setState(() => _processingIds.add(request.requestId));

    try {
      final requestRef = _firestore
          .collection('subscription_requests')
          .doc(request.requestId);

      final userRef = _firestore.collection('users').doc(request.userId);

      final batch = _firestore.batch();

      batch.set(requestRef, {
        'status': 'rejected',
        'rejectionReason': reason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': _auth.currentUser?.uid ?? '',
        'reviewedByEmail': _auth.currentUser?.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(userRef, {
        'subscriptionRequestStatus': 'rejected',
        'subscriptionRejectionReason': reason,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final auditRef = _firestore.collection('subscription_audit_logs').doc();

      batch.set(auditRef, {
        'auditId': auditRef.id,
        'action': 'rejected',
        'requestId': request.requestId,
        'userId': request.userId,
        'reason': reason,
        'performedBy': _auth.currentUser?.uid ?? '',
        'performedByEmail': _auth.currentUser?.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      _showMessage('Subscription request reject ho gayi.', success: true);
    } catch (error) {
      _showMessage('Request reject nahi ho saki: $error', success: false);
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(request.requestId));
      }
    }
  }

  Future<bool> _showApproveConfirmation(
    SubscriptionRequestModel request,
  ) async {
    final expiry = DateTime.now().add(Duration(days: request.durationDays));

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AdminSubscriptionColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            icon: const Icon(
              Icons.verified_rounded,
              color: AdminSubscriptionColors.green,
              size: 46,
            ),
            title: const Text(
              'Approve Subscription?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AdminSubscriptionColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              '${request.userName}\n'
              '${request.planTitle} • ${request.currency} ${request.amount}\n'
              'Duration: ${request.durationDays} days\n'
              'Estimated expiry: ${_formatDate(expiry)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminSubscriptionColors.secondary,
                height: 1.55,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Approve'),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminSubscriptionColors.green,
                  foregroundColor: const Color(0xFF04130A),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message, {required bool success}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success
              ? AdminSubscriptionColors.green
              : AdminSubscriptionColors.red,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminSubscriptionColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<List<SubscriptionRequestModel>>(
                stream: _watchRequests(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ErrorState(message: snapshot.error.toString());
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final requests = snapshot.data!;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1320
                          ? 3
                          : constraints.maxWidth >= 850
                          ? 2
                          : 1;

                      return CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                            sliver: SliverToBoxAdapter(
                              child: _buildOverview(requests),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                            sliver: SliverToBoxAdapter(child: _buildFilters()),
                          ),
                          if (requests.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyState(),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: columns == 1
                                          ? 1.22
                                          : 1.04,
                                    ),
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final request = requests[index];

                                  return _SubscriptionRequestCard(
                                    request: request,
                                    processing: _processingIds.contains(
                                      request.requestId,
                                    ),
                                    onApprove: () => _approve(request),
                                    onReject: () => _reject(request),
                                  );
                                }, childCount: requests.length),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      decoration: const BoxDecoration(
        color: AdminSubscriptionColors.surface,
        border: Border(
          bottom: BorderSide(color: AdminSubscriptionColors.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AdminSubscriptionColors.gradient,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscription Requests',
                  style: TextStyle(
                    color: AdminSubscriptionColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Review payments and activate premium access',
                  style: TextStyle(
                    color: AdminSubscriptionColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(List<SubscriptionRequestModel> requests) {
    final pending = requests.where((item) => item.status == 'pending').length;
    final approved = requests.where((item) => item.status == 'approved').length;
    final rejected = requests.where((item) => item.status == 'rejected').length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(
          label: 'Visible Requests',
          value: '${requests.length}',
          icon: Icons.receipt_long_rounded,
          color: AdminSubscriptionColors.cyan,
        ),
        _SummaryCard(
          label: 'Pending',
          value: '$pending',
          icon: Icons.schedule_rounded,
          color: AdminSubscriptionColors.orange,
        ),
        _SummaryCard(
          label: 'Approved',
          value: '$approved',
          icon: Icons.check_circle_outline_rounded,
          color: AdminSubscriptionColors.green,
        ),
        _SummaryCard(
          label: 'Rejected',
          value: '$rejected',
          icon: Icons.cancel_outlined,
          color: AdminSubscriptionColors.red,
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        final search = TextField(
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
          style: const TextStyle(color: AdminSubscriptionColors.text),
          decoration: InputDecoration(
            hintText: 'Search user, email, transaction ID or request ID...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AdminSubscriptionColors.surface,
            border: _fieldBorder(AdminSubscriptionColors.border),
            enabledBorder: _fieldBorder(AdminSubscriptionColors.border),
            focusedBorder: _fieldBorder(
              AdminSubscriptionColors.cyan,
              width: 1.4,
            ),
          ),
        );



        final statusButtons = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip('pending', 'Pending'),
            _filterChip('approved', 'Approved'),
            _filterChip('rejected', 'Rejected'),
            _filterChip('all', 'All'),
          ],
        );

        if (compact) {
          return Column(
            children: [
              search,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: statusButtons),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 14),
            statusButtons,
          ],
        );
      },
    );
  }

  Widget _filterChip(String value, String label) {
    return ChoiceChip(
      selected: _statusFilter == value,
      label: Text(label),
      onSelected: (_) {
        setState(() => _statusFilter = value);
      },
    );
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }
}

class _SubscriptionRequestCard extends StatelessWidget {
  const _SubscriptionRequestCard({
    required this.request,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });

  final SubscriptionRequestModel request;
  final bool processing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  Future<void> _openScreenshot(BuildContext context) async {
    final uri = Uri.tryParse(request.paymentScreenshotUrl);

    if (uri == null || !await canLaunchUrl(uri)) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Screenshot could not be opened.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (request.status) {
      'approved' => AdminSubscriptionColors.green,
      'rejected' => AdminSubscriptionColors.red,
      _ => AdminSubscriptionColors.orange,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AdminSubscriptionColors.cyan.withOpacity(.11),
                child: Text(
                  request.initials,
                  style: const TextStyle(
                    color: AdminSubscriptionColors.cyan,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminSubscriptionColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      request.userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminSubscriptionColors.muted,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: request.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 15),
          _DataRow(label: 'Plan', value: request.planTitle),
          _DataRow(
            label: 'Amount',
            value: '${request.currency} ${request.amount}',
          ),
          _DataRow(label: 'Transaction ID', value: request.transactionId),
          _DataRow(label: 'Sender', value: request.senderName),
          _DataRow(label: 'Submitted', value: request.formattedCreatedAt),
          if (request.rejectionReason.isNotEmpty)
            _DataRow(label: 'Reason', value: request.rejectionReason),
          const Spacer(),
          if (request.paymentScreenshotUrl.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openScreenshot(context),
                icon: const Icon(Icons.image_outlined),
                label: const Text('View Payment Screenshot'),
              ),
            ),
          if (request.status == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: processing ? null : onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminSubscriptionColors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: processing ? null : onApprove,
                    icon: processing
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(processing ? 'Processing' : 'Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminSubscriptionColors.green,
                      foregroundColor: const Color(0xFF04130A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SubscriptionRequestModel {
  const SubscriptionRequestModel({
    required this.requestId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.planId,
    required this.planTitle,
    required this.amount,
    required this.currency,
    required this.durationDays,
    required this.transactionId,
    required this.senderName,
    required this.senderAccount,
    required this.notes,
    required this.paymentScreenshotUrl,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });

  final String requestId;
  final String userId;
  final String userName;
  final String userEmail;
  final String planId;
  final String planTitle;
  final int amount;
  final String currency;
  final int durationDays;
  final String transactionId;
  final String senderName;
  final String senderAccount;
  final String notes;
  final String paymentScreenshotUrl;
  final String status;
  final String rejectionReason;
  final DateTime? createdAt;

  String get initials {
    final parts = userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get formattedCreatedAt {
    final value = createdAt;
    if (value == null) return 'Not available';

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  factory SubscriptionRequestModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return SubscriptionRequestModel(
      requestId: _string(data['requestId'], fallback: document.id),
      userId: _string(data['userId']),
      userName: _string(data['userName'], fallback: 'IELTS Learner'),
      userEmail: _string(data['userEmail']),
      planId: _string(data['planId']),
      planTitle: _string(data['planTitle'], fallback: 'Premium Plan'),
      amount: _integer(data['amount']),
      currency: _string(data['currency'], fallback: 'PKR'),
      durationDays: _integer(data['durationDays'], fallback: 30),
      transactionId: _string(data['transactionId']),
      senderName: _string(data['senderName']),
      senderAccount: _string(data['senderAccount']),
      notes: _string(data['notes']),
      paymentScreenshotUrl: _string(data['paymentScreenshotUrl']),
      status: _string(data['status'], fallback: 'pending').toLowerCase(),
      rejectionReason: _string(data['rejectionReason']),
      createdAt: _date(data['createdAt']),
    );
  }

  static String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _integer(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.11),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AdminSubscriptionColors.muted,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: AdminSubscriptionColors.muted,
                fontSize: 9.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AdminSubscriptionColors.text,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.11),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.payments_outlined,
            color: AdminSubscriptionColors.cyan,
            size: 54,
          ),
          SizedBox(height: 12),
          Text(
            'No subscription requests',
            style: TextStyle(
              color: AdminSubscriptionColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Requests matching the selected filter will appear here.',
            style: TextStyle(color: AdminSubscriptionColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AdminSubscriptionColors.red),
      ),
    );
  }
}

class AdminSubscriptionColors {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF111D2F);
  static const border = Color(0xFF26374F);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
  static const cyan = Color(0xFF22D3EE);
  static const blue = Color(0xFF3B82F6);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);

  static const gradient = LinearGradient(
    colors: [cyan, blue, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AdminSubscriptionColors.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AdminSubscriptionColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.10),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );
}
