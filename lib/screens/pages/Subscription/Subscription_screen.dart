import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static const String monthlyId = 'ielts_premium_monthly';
  static const String quarterlyId = 'ielts_premium_quarterly';
  static const String yearlyId = 'ielts_premium_yearly';

  static const Set<String> _productIds = {monthlyId, quarterlyId, yearlyId};

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  List<ProductDetails> _products = const [];
  bool _storeAvailable = false;
  bool _loadingProducts = true;
  bool _processingPurchase = false;
  bool _restoring = false;
  String? _storeError;

  bool _isPremium = false;
  String _premiumPlan = '';
  String _subscriptionState = '';
  DateTime? _subscriptionExpiry;
  bool _autoRenewing = false;

  User get _user {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('User is not signed in.');
    return user;
  }

  @override
  void initState() {
    super.initState();

    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _processingPurchase = false);
        _showMessage(
          'We could not receive the latest purchase update from Google Play. Please try again.',
          title: 'Purchase Update Failed',
          error: true,
        );
      },
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _profileSub = _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(_applyProfile);
    }

    _initializeStore();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeStore() async {
    if (!mounted) return;

    setState(() {
      _loadingProducts = true;
      _storeError = null;
    });

    try {
      _storeAvailable = await _iap.isAvailable();

      if (!_storeAvailable) {
        if (!mounted) return;
        setState(() {
          _loadingProducts = false;
          _storeError =
              'Google Play Billing is not available on this device/account.';
        });
        return;
      }

      final response = await _iap.queryProductDetails(_productIds);

      if (!mounted) return;

      setState(() {
        _products = response.productDetails.toList()
          ..sort((a, b) => _planRank(a.id).compareTo(_planRank(b.id)));
        _loadingProducts = false;
        _storeError = response.error?.message;
      });

      if (response.notFoundIDs.isNotEmpty) {
        _storeError =
            'Products not active in Play Console: ${response.notFoundIDs.join(', ')}';
      }

      await _syncSubscriptionFromBackend(showMessage: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _storeError = 'Could not load Google Play subscriptions: $error';
      });
    }
  }

  void _applyProfile(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final expiry = data['subscriptionExpiry'];

    DateTime? expiryDate;
    if (expiry is Timestamp) {
      expiryDate = expiry.toDate();
    } else if (expiry is String) {
      expiryDate = DateTime.tryParse(expiry);
    }

    if (!mounted) return;
    setState(() {
      _isPremium = data['isPremium'] == true || data['premium'] == true;
      _premiumPlan = (data['premiumPlan'] ?? data['subscription'] ?? '')
          .toString();
      _subscriptionState = (data['googlePlaySubscriptionState'] ?? '')
          .toString();
      _subscriptionExpiry = expiryDate;
      _autoRenewing = data['googlePlayAutoRenewing'] == true;
    });
  }

  Future<void> _buy(ProductDetails product) async {
    if (_processingPurchase) return;

    setState(() => _processingPurchase = true);

    try {
      final purchaseParam = PurchaseParam(productDetails: product);

      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!started && mounted) {
        setState(() => _processingPurchase = false);
        _showMessage(
          'Google Play could not start the payment screen. Please check your Play Store account and try again.',
          title: 'Payment Could Not Start',
          error: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _processingPurchase = false);
      _showMessage(
        'The purchase could not be started. Please try again in a moment.',
        title: 'Purchase Failed',
        error: true,
      );
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      if (!_productIds.contains(purchase.productID)) {
        if (purchase.pendingCompletePurchase) {
          await _safeCompletePurchase(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          if (mounted) setState(() => _processingPurchase = true);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndActivate(purchase);
          break;

        case PurchaseStatus.error:
          if (mounted) setState(() => _processingPurchase = false);
          _showMessage(
            purchase.error?.message ??
                'Google Play could not complete your payment. No Premium access was activated.',
            title: 'Payment Unsuccessful',
            error: true,
          );
          if (purchase.pendingCompletePurchase) {
            await _safeCompletePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          if (mounted) setState(() => _processingPurchase = false);
          _showMessage(
            'You cancelled the Google Play purchase. No charge was completed.',
            title: 'Purchase Cancelled',
            warning: true,
          );
          if (purchase.pendingCompletePurchase) {
            await _safeCompletePurchase(purchase);
          }
          break;
      }
    }
  }

  Future<void> _verifyAndActivate(PurchaseDetails purchase) async {
    try {
      final token = purchase.verificationData.serverVerificationData.trim();

      if (token.isEmpty) {
        throw StateError('Google Play purchase token is missing.');
      }

      final callable = _functions.httpsCallable('verifyGooglePlaySubscription');

      final response = await callable.call(<String, dynamic>{
        'productId': purchase.productID,
        'purchaseToken': token,
      });

      final data = Map<String, dynamic>.from(response.data as Map);

      if (data['verified'] != true || data['isPremium'] != true) {
        throw StateError(
          (data['message'] ?? 'Subscription could not be verified.').toString(),
        );
      }

      await _safeCompletePurchase(purchase);

      if (!mounted) return;

      setState(() => _processingPurchase = false);

      _showMessage(
        '${_planTitle(purchase.productID)} has been verified and Premium is now active.',
        title: 'Payment Successful',
        success: true,
      );

      _showSuccessDialog(
        planTitle: _planTitle(purchase.productID),
        expiry: _dateFromAny(data['expiryTime']),
        autoRenewing: data['autoRenewing'] == true,
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => _processingPurchase = false);
      _showMessage(
        error.message ??
            'Your payment could not be securely verified with Google Play. Premium was not activated.',
        title: 'Verification Failed',
        error: true,
      );
    } catch (error) {
      if (mounted) setState(() => _processingPurchase = false);
      _showMessage(
        'We could not verify this Google Play purchase. Please use Restore Purchases or try again.',
        title: 'Verification Failed',
        error: true,
      );
    }
  }

  Future<void> _safeCompletePurchase(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;

    try {
      await _iap.completePurchase(purchase);
    } catch (_) {
      // The backend also acknowledges valid Google Play subscriptions.
      // A second acknowledgement attempt must not remove the entitlement.
    }
  }

  Future<void> _restorePurchases() async {
    if (_restoring) return;

    setState(() => _restoring = true);

    try {
      await _iap.restorePurchases();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await _syncSubscriptionFromBackend(showMessage: true);
    } catch (error) {
      _showMessage(
        'We could not restore your Google Play purchases. Please check your Play Store account and try again.',
        title: 'Restore Failed',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _syncSubscriptionFromBackend({required bool showMessage}) async {
    try {
      final callable = _functions.httpsCallable('syncGooglePlaySubscription');
      final response = await callable.call();
      final data = Map<String, dynamic>.from(response.data as Map);

      if (showMessage) {
        if (data['isPremium'] == true) {
          _showMessage(
            'Your Google Play Premium access is active and synced with this account.',
            title: 'Premium Active',
            success: true,
          );
        } else {
          _showMessage(
            (data['message'] ?? 'No active Google Play subscription was found.')
                .toString(),
            title: 'No Active Subscription',
            warning: true,
          );
        }
      }
    } on FirebaseFunctionsException catch (error) {
      if (showMessage) {
        _showMessage(
          error.message ?? 'Subscription status could not be refreshed.',
          title: 'Refresh Failed',
          error: true,
        );
      }
    } catch (error) {
      if (showMessage) {
        _showMessage(
          'Subscription status could not be refreshed. Please try again.',
          title: 'Refresh Failed',
          error: true,
        );
      }
    }
  }

  void _showMessage(
    String message, {
    String? title,
    bool error = false,
    bool success = false,
    bool warning = false,
  }) {
    if (!mounted) return;

    final type = error
        ? _SubscriptionSnackType.error
        : success
        ? _SubscriptionSnackType.success
        : warning
        ? _SubscriptionSnackType.warning
        : _SubscriptionSnackType.info;

    final config = _snackConfig(type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          padding: EdgeInsets.zero,
          duration: Duration(
            seconds: type == _SubscriptionSnackType.error ? 5 : 4,
          ),
          dismissDirection: DismissDirection.horizontal,
          content: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  config.color.withOpacity(.22),
                  SubscriptionColors.surface2.withOpacity(.98),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: config.color.withOpacity(.48),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(color: config.color.withOpacity(.08), blurRadius: 20),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: config.color.withOpacity(.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: config.color.withOpacity(.26)),
                  ),
                  child: Icon(config.icon, color: config.color, size: 22),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title ?? config.defaultTitle,
                        style: const TextStyle(
                          color: SubscriptionColors.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: const TextStyle(
                          color: SubscriptionColors.secondary,
                          fontSize: 10.5,
                          height: 1.42,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Dismiss',
                  onPressed: () =>
                      ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: SubscriptionColors.muted,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Future<void> _showSuccessDialog({
    required String planTitle,
    required DateTime? expiry,
    required bool autoRenewing,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: SubscriptionColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          icon: Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SubscriptionColors.gradient,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          title: const Text(
            'Premium Activated',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SubscriptionColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            '$planTitle is active.${expiry == null ? '' : '\n\nAccess until ${_formatDate(expiry)}.'}'
            '${autoRenewing ? '\n\nGoogle Play will renew this plan automatically unless you cancel it.' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SubscriptionColors.secondary,
              height: 1.55,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(
        backgroundColor: SubscriptionColors.background,
        body: Center(
          child: Text(
            'Please sign in to manage Premium.',
            style: TextStyle(color: SubscriptionColors.text),
          ),
        ),
      );
    }

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
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await _initializeStore();
                      await _syncSubscriptionFromBackend(showMessage: false);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                      children: [
                        _buildHero(),
                        const SizedBox(height: 16),
                        if (_isPremium) ...[
                          _buildActiveSubscriptionCard(),
                          const SizedBox(height: 16),
                        ],
                        _buildBenefits(),
                        const SizedBox(height: 18),
                        _buildPlans(),
                        const SizedBox(height: 18),
                        _buildGooglePlayNotice(),
                        const SizedBox(height: 16),
                        _buildRestoreCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_processingPurchase)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(.56),
                alignment: Alignment.center,
                child: Container(
                  margin: const EdgeInsets.all(28),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: SubscriptionColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: SubscriptionColors.border),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: SubscriptionColors.cyan),
                      SizedBox(height: 16),
                      Text(
                        'Confirming with Google Play...',
                        style: TextStyle(
                          color: SubscriptionColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Premium is enabled only after secure server verification.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: SubscriptionColors.muted,
                          fontSize: 10.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
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
          const SizedBox(width: 10),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: SubscriptionColors.gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: SubscriptionColors.cyan.withOpacity(.18),
                  blurRadius: 22,
                ),
              ],
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
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Secure billing by Google Play',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unlock unlimited IELTS practice',
            style: TextStyle(
              color: SubscriptionColors.text,
              fontSize: 25,
              height: 1.16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Subscribe through Google Play. Payments, renewals and cancellation are handled by your Google Play account.',
            style: TextStyle(
              color: SubscriptionColors.secondary,
              fontSize: 11.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FeatureChip(
                icon: Icons.all_inclusive_rounded,
                label: 'Unlimited Practice',
              ),
              _FeatureChip(icon: Icons.auto_awesome_rounded, label: 'AI Coach'),
              _FeatureChip(
                icon: Icons.bar_chart_rounded,
                label: 'Full Analytics',
              ),
              _FeatureChip(
                icon: Icons.verified_rounded,
                label: 'Secure Verification',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubscriptionCard() {
    final expiryText = _subscriptionExpiry == null
        ? 'Active'
        : 'Access until ${_formatDate(_subscriptionExpiry!)}';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SubscriptionColors.green.withOpacity(.18),
            SubscriptionColors.cyan.withOpacity(.10),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SubscriptionColors.green.withOpacity(.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: SubscriptionColors.green.withOpacity(.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: SubscriptionColors.green,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Premium is active',
                  style: TextStyle(
                    color: SubscriptionColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_premiumPlan.isEmpty ? 'Google Play subscription' : _premiumPlan} • $expiryText',
                  style: const TextStyle(
                    color: SubscriptionColors.secondary,
                    fontSize: 10.5,
                    height: 1.45,
                  ),
                ),
                if (_subscriptionState.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _autoRenewing
                        ? 'Auto-renewal is enabled'
                        : 'Auto-renewal is not enabled',
                    style: const TextStyle(
                      color: SubscriptionColors.green,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefits() {
    return _SectionCard(
      title: 'Premium Benefits',
      subtitle: 'Everything included with your subscription',
      icon: Icons.stars_rounded,
      child: const Column(
        children: [
          _BenefitRow(
            icon: Icons.headphones_rounded,
            title: 'Unlimited Listening',
            subtitle: 'Remove the free daily Listening limit.',
          ),
          _BenefitDivider(),
          _BenefitRow(
            icon: Icons.menu_book_rounded,
            title: 'Unlimited Reading',
            subtitle: 'Practice without the free daily Reading limit.',
          ),
          _BenefitDivider(),
          _BenefitRow(
            icon: Icons.psychology_alt_rounded,
            title: 'AI Coach & Insights',
            subtitle: 'Use personalized performance recommendations.',
          ),
          _BenefitDivider(),
          _BenefitRow(
            icon: Icons.analytics_outlined,
            title: 'Advanced Analytics',
            subtitle: 'Track bands, weak areas and study progress.',
          ),
        ],
      ),
    );
  }

  Widget _buildPlans() {
    if (_loadingProducts) {
      return _SectionCard(
        title: 'Choose Your Plan',
        subtitle: 'Loading prices from Google Play',
        icon: Icons.sell_outlined,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(color: SubscriptionColors.cyan),
          ),
        ),
      );
    }

    if (_storeError != null || _products.isEmpty) {
      return _SectionCard(
        title: 'Choose Your Plan',
        subtitle: 'Google Play products are not ready',
        icon: Icons.error_outline_rounded,
        child: Column(
          children: [
            Text(
              _storeError ??
                  'No active subscription products were returned by Google Play.',
              style: const TextStyle(
                color: SubscriptionColors.secondary,
                fontSize: 11,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _initializeStore,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      title: 'Choose Your Plan',
      subtitle: 'Prices below come directly from Google Play',
      icon: Icons.sell_outlined,
      child: Column(
        children: _products
            .map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _GooglePlayPlanTile(
                  product: product,
                  title: _planTitle(product.id),
                  subtitle: _planDescription(product.id),
                  badge: _planBadge(product.id),
                  enabled: !_processingPurchase,
                  onTap: () => _buy(product),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildGooglePlayNotice() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _panelDecoration(
        borderColor: SubscriptionColors.cyan.withOpacity(.26),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_good_rounded, color: SubscriptionColors.cyan),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Google Play handles the payment method and recurring charge. Auto-renewing plans renew at the displayed billing frequency until cancelled. Premium is granted only after the app sends the purchase token to Firebase and Google Play verifies it.',
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

  Widget _buildRestoreCard() {
    return _SectionCard(
      title: 'Already subscribed?',
      subtitle: 'Restore or refresh your Google Play entitlement',
      icon: Icons.restore_rounded,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _restoring ? null : _restorePurchases,
              icon: _restoring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore_rounded),
              label: Text(_restoring ? 'Restoring...' : 'Restore Purchases'),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Refresh subscription status',
            onPressed: () => _syncSubscriptionFromBackend(showMessage: true),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
    );
  }

  static int _planRank(String productId) {
    switch (productId) {
      case monthlyId:
        return 1;
      case quarterlyId:
        return 2;
      case yearlyId:
        return 3;
      default:
        return 99;
    }
  }

  static String _planTitle(String productId) {
    switch (productId) {
      case monthlyId:
        return 'Monthly Premium';
      case quarterlyId:
        return '3-Month Premium';
      case yearlyId:
        return 'Annual Premium';
      default:
        return 'Premium';
    }
  }

  static String _planDescription(String productId) {
    switch (productId) {
      case monthlyId:
        return 'Renews every month until cancelled.';
      case quarterlyId:
        return 'Renews every 3 months until cancelled.';
      case yearlyId:
        return 'Renews every year until cancelled.';
      default:
        return 'Recurring Google Play subscription.';
    }
  }

  static String _planBadge(String productId) {
    switch (productId) {
      case quarterlyId:
        return 'POPULAR';
      case yearlyId:
        return 'BEST VALUE';
      default:
        return '';
    }
  }

  static DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _GooglePlayPlanTile extends StatelessWidget {
  const _GooglePlayPlanTile({
    required this.product,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.enabled,
    required this.onTap,
  });

  final ProductDetails product;
  final String title;
  final String subtitle;
  final String badge;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(19),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SubscriptionColors.background.withOpacity(.36),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: badge.isNotEmpty
                  ? SubscriptionColors.cyan.withOpacity(.44)
                  : SubscriptionColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: SubscriptionColors.gradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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
                            title,
                            style: const TextStyle(
                              color: SubscriptionColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (badge.isNotEmpty) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: SubscriptionColors.violet.withOpacity(.14),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              badge,
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
                      subtitle,
                      style: const TextStyle(
                        color: SubscriptionColors.muted,
                        fontSize: 9.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    product.price,
                    style: const TextStyle(
                      color: SubscriptionColors.cyan,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Google Play',
                    style: TextStyle(
                      color: SubscriptionColors.muted,
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SubscriptionColors.cyan.withOpacity(.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: SubscriptionColors.cyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: SubscriptionColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
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
          const Icon(
            Icons.check_circle_rounded,
            color: SubscriptionColors.green,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _BenefitDivider extends StatelessWidget {
  const _BenefitDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: SubscriptionColors.border);
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

class _SubscriptionBackground extends StatelessWidget {
  const _SubscriptionBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SubscriptionColors.violet.withOpacity(.08),
              ),
            ),
          ),
          Positioned(
            top: 180,
            left: -130,
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SubscriptionColors.cyan.withOpacity(.055),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SubscriptionSnackType { success, error, warning, info }

class _SubscriptionSnackConfig {
  final Color color;
  final IconData icon;
  final String defaultTitle;

  const _SubscriptionSnackConfig({
    required this.color,
    required this.icon,
    required this.defaultTitle,
  });
}

_SubscriptionSnackConfig _snackConfig(_SubscriptionSnackType type) {
  switch (type) {
    case _SubscriptionSnackType.success:
      return const _SubscriptionSnackConfig(
        color: SubscriptionColors.green,
        icon: Icons.check_circle_rounded,
        defaultTitle: 'Success',
      );
    case _SubscriptionSnackType.error:
      return const _SubscriptionSnackConfig(
        color: SubscriptionColors.red,
        icon: Icons.error_rounded,
        defaultTitle: 'Something Went Wrong',
      );
    case _SubscriptionSnackType.warning:
      return const _SubscriptionSnackConfig(
        color: SubscriptionColors.orange,
        icon: Icons.info_rounded,
        defaultTitle: 'Attention',
      );
    case _SubscriptionSnackType.info:
      return const _SubscriptionSnackConfig(
        color: SubscriptionColors.cyan,
        icon: Icons.info_outline_rounded,
        defaultTitle: 'Google Play',
      );
  }
}

class SubscriptionColors {
  static const background = Color(0xFF07101D);
  static const surface = Color(0xFF101C2C);
  static const surface2 = Color(0xFF152235);
  static const border = Color(0xFF223149);
  static const text = Color(0xFFF7FAFC);
  static const secondary = Color(0xFFB5C1D1);
  static const muted = Color(0xFF75849A);
  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
  );
}

BoxDecoration _panelDecoration({Color? borderColor}) {
  return BoxDecoration(
    color: SubscriptionColors.surface.withOpacity(.94),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: borderColor ?? SubscriptionColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.15),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

BoxDecoration _heroDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        SubscriptionColors.blue.withOpacity(.25),
        SubscriptionColors.cyan.withOpacity(.10),
        SubscriptionColors.violet.withOpacity(.18),
      ],
    ),
    borderRadius: BorderRadius.circular(26),
    border: Border.all(color: SubscriptionColors.cyan.withOpacity(.20)),
    boxShadow: [
      BoxShadow(
        color: SubscriptionColors.cyan.withOpacity(.06),
        blurRadius: 28,
        offset: const Offset(0, 14),
      ),
    ],
  );
}
