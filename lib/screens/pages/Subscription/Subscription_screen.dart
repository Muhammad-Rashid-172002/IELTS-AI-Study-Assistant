import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static const String bankName = 'Bank Alfalah';
  static const String accountTitle = 'Muhammad Rashid';
  static const String iban = 'PK82ALFH5763005002775917';
  static const String accountNumber = '57635002775917';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _transactionIdController =
      TextEditingController();
  final TextEditingController _senderNameController = TextEditingController();
  final TextEditingController _senderAccountController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  SubscriptionPlan _selectedPlan = SubscriptionPlan.monthly;
  XFile? _paymentScreenshot;
  bool _isSubmitting = false;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User is not signed in.');
    return user;
  }

  @override
  void dispose() {
    _transactionIdController.dispose();
    _senderNameController.dispose();
    _senderAccountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _copyValue(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _pickScreenshot() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (image == null) return;

    final bytes = await image.length();
    if (bytes > 8 * 1024 * 1024) {
      _showError('Screenshot size must be less than 8 MB.');
      return;
    }

    setState(() => _paymentScreenshot = image);
  }

  Future<void> _submitPaymentProof() async {
    if (_isSubmitting) return;

    final transactionId = _transactionIdController.text.trim();
    final senderName = _senderNameController.text.trim();

    if (transactionId.length < 4) {
      _showError('Please enter a valid transaction ID.');
      return;
    }
    if (senderName.length < 2) {
      _showError('Please enter the sender/account holder name.');
      return;
    }
    if (_paymentScreenshot == null) {
      _showError('Please upload the payment screenshot.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _user;
      final requestRef = _firestore.collection('subscription_requests').doc();

      final screenshotUrl = await _uploadScreenshot(
        uid: user.uid,
        requestId: requestRef.id,
        image: _paymentScreenshot!,
      );

      final now = FieldValue.serverTimestamp();

      await requestRef.set({
        'requestId': requestRef.id,
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'userName': user.displayName ?? '',
        'planId': _selectedPlan.id,
        'planTitle': _selectedPlan.title,
        'amount': _selectedPlan.price,
        'currency': 'PKR',
        'durationDays': _selectedPlan.durationDays,
        'transactionId': transactionId,
        'senderName': senderName,
        'senderAccount': _senderAccountController.text.trim(),
        'notes': _notesController.text.trim(),
        'paymentMethod': 'Bank Transfer',
        'bankName': bankName,
        'accountTitle': accountTitle,
        'iban': iban,
        'accountNumber': accountNumber,
        'paymentScreenshotUrl': screenshotUrl,
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
      });

      await _firestore.collection('users').doc(user.uid).set({
        'subscriptionRequestStatus': 'pending',
        'subscriptionRequestId': requestRef.id,
        'subscriptionPlanRequested': _selectedPlan.id,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SubmissionSuccessDialog(
          requestId: requestRef.id,
          plan: _selectedPlan,
        ),
      );

      if (!mounted) return;
      setState(() {
        _transactionIdController.clear();
        _senderNameController.clear();
        _senderAccountController.clear();
        _notesController.clear();
        _paymentScreenshot = null;
      });
    } on FirebaseException catch (error) {
      _showError(error.message ?? 'Payment proof could not be submitted.');
    } catch (_) {
      _showError('Payment proof could not be submitted. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<String> _uploadScreenshot({
    required String uid,
    required String requestId,
    required XFile image,
  }) async {
    final extension = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';

    final ref = _storage.ref(
      'subscription_payment_proofs/$uid/$requestId/payment.$extension',
    );

    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      await ref.putData(
        bytes,
        SettableMetadata(contentType: _contentType(extension)),
      );
    } else {
      await ref.putFile(
        File(image.path),
        SettableMetadata(contentType: _contentType(extension)),
      );
    }

    return ref.getDownloadURL();
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SubscriptionColors.red,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SubscriptionColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _SubscriptionBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHero(),
                            const SizedBox(height: 18),
                            _buildPlanSection(),
                            const SizedBox(height: 18),
                            _buildBankDetails(),
                            const SizedBox(height: 18),
                            _buildPaymentForm(),
                            const SizedBox(height: 18),
                            _buildNotice(),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : _submitPaymentProof,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 19,
                                        height: 19,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.verified_user_rounded),
                                label: Text(
                                  _isSubmitting
                                      ? 'Submitting Payment...'
                                      : 'Submit Payment Proof',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: SubscriptionColors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 18, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              backgroundColor: SubscriptionColors.surface,
              foregroundColor: SubscriptionColors.text,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 11),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: SubscriptionColors.gradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IELTS AI Master Premium',
                  style: TextStyle(
                    color: SubscriptionColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Upgrade your learning experience',
                  style: TextStyle(
                    color: SubscriptionColors.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _heroDecoration(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unlock your complete IELTS preparation journey',
            style: TextStyle(
              color: SubscriptionColors.text,
              fontSize: 25,
              height: 1.18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 11),
          Text(
            'Choose a plan, transfer the payment to the official bank account, and upload your payment proof for review.',
            style: TextStyle(
              color: SubscriptionColors.secondary,
              fontSize: 11.5,
              height: 1.55,
            ),
          ),
          SizedBox(height: 17),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeatureChip(icon: Icons.auto_awesome_rounded, label: 'AI Coach'),
              _FeatureChip(
                icon: Icons.all_inclusive_rounded,
                label: 'Unlimited Practice',
              ),
              _FeatureChip(
                icon: Icons.bar_chart_rounded,
                label: 'Detailed Analytics',
              ),
              _FeatureChip(
                icon: Icons.workspace_premium_rounded,
                label: 'Certificates',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSection() {
    return _SectionCard(
      title: 'Choose Your Plan',
      subtitle: 'Select the membership that suits your preparation.',
      icon: Icons.sell_outlined,
      child: Column(
        children: SubscriptionPlan.values
            .map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _PlanTile(
                  plan: plan,
                  selected: _selectedPlan == plan,
                  onTap: () => setState(() => _selectedPlan = plan),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBankDetails() {
    return _SectionCard(
      title: 'Bank Transfer Details',
      subtitle: 'Transfer the exact selected plan amount.',
      icon: Icons.account_balance_rounded,
      child: Column(
        children: [
          _CopyDetailTile(
            label: 'Bank',
            value: bankName,
            icon: Icons.account_balance_outlined,
            onCopy: () => _copyValue(bankName, 'Bank name copied.'),
          ),
          _CopyDetailTile(
            label: 'Account Title',
            value: accountTitle,
            icon: Icons.person_outline_rounded,
            onCopy: () => _copyValue(accountTitle, 'Account title copied.'),
          ),
          _CopyDetailTile(
            label: 'IBAN',
            value: iban,
            icon: Icons.credit_card_rounded,
            onCopy: () => _copyValue(iban, 'IBAN copied.'),
          ),
          _CopyDetailTile(
            label: 'Account Number',
            value: accountNumber,
            icon: Icons.numbers_rounded,
            onCopy: () => _copyValue(accountNumber, 'Account number copied.'),
            divider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return _SectionCard(
      title: 'Submit Payment Proof',
      subtitle: 'Your request will be reviewed before activation.',
      icon: Icons.receipt_long_rounded,
      child: Column(
        children: [
          TextField(
            controller: _transactionIdController,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: SubscriptionColors.text),
            decoration: const InputDecoration(
              labelText: 'Transaction ID *',
              hintText: 'Example: FT24123456789',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _senderNameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: SubscriptionColors.text),
            decoration: const InputDecoration(
              labelText: 'Sender / Account Holder Name *',
              hintText: 'Name used for payment',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _senderAccountController,
            style: const TextStyle(color: SubscriptionColors.text),
            decoration: const InputDecoration(
              labelText: 'Sender Account / Wallet Number',
              hintText: 'Optional',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(color: SubscriptionColors.text),
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Add any helpful payment details...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 15),
          _ScreenshotPicker(
            image: _paymentScreenshot,
            onPick: _pickScreenshot,
            onRemove: () => setState(() => _paymentScreenshot = null),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _panelDecoration(
        borderColor: SubscriptionColors.orange.withOpacity(.35),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: SubscriptionColors.orange),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Payment verification is currently handled manually. Premium access will be activated after the administrator confirms the transaction. Do not share OTP, PIN, password, or complete card details.',
              style: TextStyle(
                color: SubscriptionColors.secondary,
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum SubscriptionPlan {
  monthly(
    id: 'monthly',
    title: 'Monthly Premium',
    price: 1499,
    durationDays: 30,
    badge: '',
    description: 'Complete premium access for one month.',
  ),
  quarterly(
    id: 'quarterly',
    title: '3-Month Premium',
    price: 3499,
    durationDays: 90,
    badge: 'POPULAR',
    description: 'Best for structured IELTS preparation.',
  ),
  yearly(
    id: 'yearly',
    title: 'Annual Premium',
    price: 9999,
    durationDays: 365,
    badge: 'BEST VALUE',
    description: 'Maximum savings for long-term preparation.',
  );

  const SubscriptionPlan({
    required this.id,
    required this.title,
    required this.price,
    required this.durationDays,
    required this.badge,
    required this.description,
  });

  final String id;
  final String title;
  final int price;
  final int durationDays;
  final String badge;
  final String description;
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? SubscriptionColors.cyan.withOpacity(.07)
              : SubscriptionColors.background.withOpacity(.36),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? SubscriptionColors.cyan
                : SubscriptionColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? SubscriptionColors.cyan
                  : SubscriptionColors.muted,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          plan.title,
                          style: const TextStyle(
                            color: SubscriptionColors.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (plan.badge.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: SubscriptionColors.violet.withOpacity(.13),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            plan.badge,
                            style: const TextStyle(
                              color: SubscriptionColors.violet,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.description,
                    style: const TextStyle(
                      color: SubscriptionColors.muted,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'PKR ${plan.price}',
              style: TextStyle(
                color: selected
                    ? SubscriptionColors.cyan
                    : SubscriptionColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyDetailTile extends StatelessWidget {
  const _CopyDetailTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onCopy,
    this.divider = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onCopy;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: SubscriptionColors.cyan.withOpacity(.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: SubscriptionColors.cyan, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: SubscriptionColors.muted,
                        fontSize: 8.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      value,
                      style: const TextStyle(
                        color: SubscriptionColors.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                onPressed: onCopy,
                icon: const Icon(
                  Icons.copy_rounded,
                  color: SubscriptionColors.secondary,
                ),
              ),
            ],
          ),
        ),
        if (divider) const Divider(height: 1, color: SubscriptionColors.border),
      ],
    );
  }
}

class _ScreenshotPicker extends StatelessWidget {
  const _ScreenshotPicker({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(
            color: SubscriptionColors.background.withOpacity(.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SubscriptionColors.border),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                color: SubscriptionColors.cyan,
                size: 38,
              ),
              SizedBox(height: 10),
              Text(
                'Upload Payment Screenshot *',
                style: TextStyle(
                  color: SubscriptionColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'PNG, JPG or WEBP • Maximum 8 MB',
                style: TextStyle(
                  color: SubscriptionColors.muted,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SubscriptionColors.background.withOpacity(.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SubscriptionColors.green.withOpacity(.35)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: kIsWeb
                  ? Image.network(image!.path, fit: BoxFit.cover)
                  : Image.file(File(image!.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: SubscriptionColors.green,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Payment screenshot selected',
                  style: TextStyle(
                    color: SubscriptionColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: SubscriptionColors.cyan.withOpacity(.10),
                child: Icon(icon, color: SubscriptionColors.cyan),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: SubscriptionColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: SubscriptionColors.muted,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: SubscriptionColors.background.withOpacity(.45),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: SubscriptionColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: SubscriptionColors.cyan, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: SubscriptionColors.secondary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionSuccessDialog extends StatelessWidget {
  const _SubmissionSuccessDialog({required this.requestId, required this.plan});

  final String requestId;
  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SubscriptionColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(
        Icons.check_circle_rounded,
        color: SubscriptionColors.green,
        size: 54,
      ),
      title: const Text(
        'Payment Submitted',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: SubscriptionColors.text,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Text(
        'Your ${plan.title} payment proof has been submitted successfully.\n\n'
        'Request ID:\n$requestId\n\n'
        'Premium access will be activated after verification.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: SubscriptionColors.secondary,
          height: 1.5,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _SubscriptionBackground extends StatelessWidget {
  const _SubscriptionBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(.72, -.92),
          radius: 1.15,
          colors: [
            SubscriptionColors.blue.withOpacity(.13),
            SubscriptionColors.violet.withOpacity(.05),
            SubscriptionColors.background,
          ],
        ),
      ),
    );
  }
}

class SubscriptionColors {
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

BoxDecoration _panelDecoration({Color? borderColor}) {
  return BoxDecoration(
    color: SubscriptionColors.surface,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: borderColor ?? SubscriptionColors.border),
  );
}

BoxDecoration _heroDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        SubscriptionColors.surface,
        SubscriptionColors.blue.withOpacity(.18),
        SubscriptionColors.cyan.withOpacity(.09),
        SubscriptionColors.violet.withOpacity(.10),
      ],
    ),
    borderRadius: BorderRadius.circular(25),
    border: Border.all(color: SubscriptionColors.cyan.withOpacity(.23)),
  );
}
