import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';

enum _UserSort { newest, lastActive, name, currentBand, targetBand }

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String _status = 'all';
  String _track = 'all';
  String _diagnostic = 'all';
  _UserSort _sort = _UserSort.newest;
  int _page = 0;
  int _pageSize = 20;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetPage() => _page = 0;

  List<_Learner> _filtered(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final query = _search.trim().toLowerCase();
    final records = documents.map(_Learner.fromDocument).where((learner) {
      final searchMatch =
          query.isEmpty ||
          learner.searchText.contains(query) ||
          learner.id.toLowerCase().contains(query);
      final statusMatch = _status == 'all' || learner.accountStatus == _status;
      final trackMatch = _track == 'all' || learner.ieltsType == _track;
      final diagnosticMatch =
          _diagnostic == 'all' ||
          (_diagnostic == 'completed' && learner.diagnosticCompleted) ||
          (_diagnostic == 'pending' && !learner.diagnosticCompleted);
      return searchMatch && statusMatch && trackMatch && diagnosticMatch;
    }).toList();

    switch (_sort) {
      case _UserSort.newest:
        records.sort(
          (a, b) => _dateValue(b.createdAt).compareTo(_dateValue(a.createdAt)),
        );
      case _UserSort.lastActive:
        records.sort(
          (a, b) =>
              _dateValue(b.lastActive).compareTo(_dateValue(a.lastActive)),
        );
      case _UserSort.name:
        records.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _UserSort.currentBand:
        records.sort((a, b) => b.currentBand.compareTo(a.currentBand));
      case _UserSort.targetBand:
        records.sort((a, b) => b.targetBand.compareTo(a.targetBand));
    }
    return records;
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Learners',
      subtitle: 'Accounts, goals, activity and assessment progress',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(500)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const LoadingView(message: 'Loading learner records...');
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error);
          }

          final documents = snapshot.data!.docs;
          final all = documents.map(_Learner.fromDocument).toList();
          final filtered = _filtered(documents);
          final pageCount = math.max(1, (filtered.length / _pageSize).ceil());
          if (_page >= pageCount) _page = pageCount - 1;
          final start = math.min(_page * _pageSize, filtered.length);
          final end = math.min(start + _pageSize, filtered.length);
          final pageItems = filtered.sublist(start, end);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              _Summary(records: all),
              const SizedBox(height: 16),
              _Filters(
                searchController: _searchController,
                status: _status,
                track: _track,
                diagnostic: _diagnostic,
                sort: _sort,
                onSearch: (value) => setState(() {
                  _search = value;
                  _resetPage();
                }),
                onStatus: (value) => setState(() {
                  _status = value;
                  _resetPage();
                }),
                onTrack: (value) => setState(() {
                  _track = value;
                  _resetPage();
                }),
                onDiagnostic: (value) => setState(() {
                  _diagnostic = value;
                  _resetPage();
                }),
                onSort: (value) => setState(() {
                  _sort = value;
                  _resetPage();
                }),
                onClear: () => setState(() {
                  _searchController.clear();
                  _search = '';
                  _status = 'all';
                  _track = 'all';
                  _diagnostic = 'all';
                  _sort = _UserSort.newest;
                  _resetPage();
                }),
              ),
              const SizedBox(height: 16),
              _Directory(
                learners: pageItems,
                filteredCount: filtered.length,
                totalCount: all.length,
                start: start,
                end: end,
                onOpen: _showDetails,
              ),
              const SizedBox(height: 10),
              _Pagination(
                page: _page,
                pages: pageCount,
                pageSize: _pageSize,
                onPrevious: _page > 0 ? () => setState(() => _page--) : null,
                onNext: _page + 1 < pageCount
                    ? () => setState(() => _page++)
                    : null,
                onPageSize: (value) => setState(() {
                  _pageSize = value;
                  _resetPage();
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDetails(_Learner learner) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _DetailsDialog(
        learner: learner,
        onChangeStatus: () {
          Navigator.pop(dialogContext);
          _confirmStatusChange(learner);
        },
      ),
    );
  }

  Future<void> _confirmStatusChange(_Learner learner) async {
    final next = learner.accountStatus == 'suspended' ? 'active' : 'suspended';
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: Text(
          next == 'suspended'
              ? 'Suspend learner account?'
              : 'Reactivate learner account?',
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                next == 'suspended'
                    ? '${learner.name} will be signed out and blocked from signing in until reactivated.'
                    : '${learner.name} will be able to sign in and continue learning again.',
                style: const TextStyle(
                  color: AdminColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Administrative note',
                  hintText: 'Add context for the audit log',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: next == 'suspended'
                ? FilledButton.styleFrom(backgroundColor: AdminColors.danger)
                : null,
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(
              next == 'suspended'
                  ? Icons.block_rounded
                  : Icons.check_circle_outline_rounded,
            ),
            label: Text(next == 'suspended' ? 'Suspend Account' : 'Reactivate'),
          ),
        ],
      ),
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Updating learner access...')),
    );

    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('setLearnerAccountStatus')
          .call({'userId': learner.id, 'status': next, 'reason': reason});
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            next == 'suspended'
                ? 'Learner account suspended.'
                : 'Learner account reactivated.',
          ),
          backgroundColor: AdminColors.success,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Account access could not be updated.',
          ),
          backgroundColor: AdminColors.danger,
        ),
      );
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.records});

  final List<_Learner> records;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = records
        .where(
          (r) =>
              r.accountStatus == 'active' &&
              r.lastActive != null &&
              now.difference(r.lastActive!).inDays <= 30,
        )
        .length;
    final newThisMonth = records
        .where(
          (r) =>
              r.createdAt?.year == now.year && r.createdAt?.month == now.month,
        )
        .length;
    final diagnostics = records.where((r) => r.diagnosticCompleted).length;
    final certificates = records.fold<int>(
      0,
      (total, learner) => total + learner.certificates,
    );
    final cards = [
      _Metric(
        'Total learners',
        '${records.length}',
        'Registered accounts',
        Icons.people_alt_outlined,
        AdminColors.cyan,
      ),
      _Metric(
        'Active learners',
        '$active',
        'Seen in the last 30 days',
        Icons.bolt_rounded,
        AdminColors.success,
      ),
      _Metric(
        'New this month',
        '$newThisMonth',
        'New registrations',
        Icons.person_add_alt_1_rounded,
        AdminColors.violet,
      ),
      _Metric(
        'Diagnostics complete',
        '$diagnostics',
        'Learners with a baseline',
        Icons.health_and_safety_outlined,
        AdminColors.warning,
      ),
      _Metric(
        'Certificates issued',
        '$certificates',
        'Verifiable achievements',
        Icons.workspace_premium_outlined,
        const Color(0xFFF97316),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 680
            ? 3
            : constraints.maxWidth >= 440
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail, this.icon, this.color);
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AdminColors.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.text,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchController,
    required this.status,
    required this.track,
    required this.diagnostic,
    required this.sort,
    required this.onSearch,
    required this.onStatus,
    required this.onTrack,
    required this.onDiagnostic,
    required this.onSort,
    required this.onClear,
  });
  final TextEditingController searchController;
  final String status;
  final String track;
  final String diagnostic;
  final _UserSort sort;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onTrack;
  final ValueChanged<String> onDiagnostic;
  final ValueChanged<_UserSort> onSort;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      _Drop<String>('Account', status, const {
        'all': 'All statuses',
        'active': 'Active',
        'suspended': 'Suspended',
      }, onStatus),
      _Drop<String>('IELTS track', track, const {
        'all': 'All tracks',
        'Academic': 'Academic',
        'General Training': 'General Training',
      }, onTrack),
      _Drop<String>('Diagnostic', diagnostic, const {
        'all': 'Any diagnostic',
        'completed': 'Completed',
        'pending': 'Pending',
      }, onDiagnostic),
      _Drop<_UserSort>('Sort by', sort, const {
        _UserSort.newest: 'Newest registration',
        _UserSort.lastActive: 'Recently active',
        _UserSort.name: 'Name A–Z',
        _UserSort.currentBand: 'Current band',
        _UserSort.targetBand: 'Target band',
      }, onSort),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            controller: searchController,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search name, email or learner ID',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        searchController.clear();
                        onSearch('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );
          if (constraints.maxWidth < 980) {
            return Column(
              children: [
                search,
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: fields),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear filters'),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 2, child: search),
              const SizedBox(width: 10),
              ...fields.expand(
                (field) => [
                  SizedBox(width: 155, child: field),
                  const SizedBox(width: 10),
                ],
              ),
              IconButton(
                tooltip: 'Clear filters',
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Drop<T> extends StatelessWidget {
  const _Drop(this.label, this.value, this.items, this.onChanged);
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items.entries
          .map(
            (e) => DropdownMenuItem<T>(
              value: e.key,
              child: Text(
                e.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _Directory extends StatelessWidget {
  const _Directory({
    required this.learners,
    required this.filteredCount,
    required this.totalCount,
    required this.start,
    required this.end,
    required this.onOpen,
  });
  final List<_Learner> learners;
  final int filteredCount;
  final int totalCount;
  final int start;
  final int end;
  final ValueChanged<_Learner> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Learner directory',
                        style: TextStyle(
                          color: AdminColors.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Open a record for goals, practice and credential details.',
                        style: TextStyle(
                          color: AdminColors.textMuted,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  filteredCount == totalCount
                      ? '$totalCount learners'
                      : '$filteredCount of $totalCount',
                  style: const TextStyle(
                    color: AdminColors.cyan,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.border),
          if (learners.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Column(
                children: [
                  Icon(
                    Icons.person_search_rounded,
                    color: AdminColors.textMuted,
                    size: 42,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No learners match these filters',
                    style: TextStyle(
                      color: AdminColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Clear one or more filters to broaden the directory.',
                    style: TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: learners
                        .map(
                          (l) => _MobileLearner(
                            learner: l,
                            onTap: () => onOpen(l),
                          ),
                        )
                        .toList(),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(1120, constraints.maxWidth),
                    child: Column(
                      children: [
                        const _TableHeader(),
                        ...learners.map(
                          (l) => _TableRow(learner: l, onTap: () => onOpen(l)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (learners.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 11, 18, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing ${start + 1}–$end of $filteredCount matching learners',
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();
  @override
  Widget build(BuildContext context) => Container(
    color: AdminColors.surfaceLight.withValues(alpha: .48),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: const Row(
      children: [
        Expanded(flex: 24, child: _Label('LEARNER')),
        Expanded(flex: 12, child: _Label('STATUS')),
        Expanded(flex: 13, child: _Label('IELTS TRACK')),
        Expanded(flex: 12, child: _Label('BAND GOAL')),
        Expanded(flex: 13, child: _Label('DIAGNOSTIC')),
        Expanded(flex: 12, child: _Label('LAST ACTIVE')),
        Expanded(flex: 10, child: _Label('PRACTICE')),
        SizedBox(width: 38),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AdminColors.textMuted,
      fontSize: 8.5,
      fontWeight: FontWeight.w800,
      letterSpacing: .7,
    ),
  );
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.learner, required this.onTap});
  final _Learner learner;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 24, child: _Identity(learner)),
          Expanded(
            flex: 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(status: learner.accountStatus),
            ),
          ),
          Expanded(flex: 13, child: _Cell(learner.ieltsType)),
          Expanded(flex: 12, child: _BandGoal(learner)),
          Expanded(flex: 13, child: _Diagnostic(learner.diagnosticCompleted)),
          Expanded(flex: 12, child: _Cell(_relative(learner.lastActive))),
          Expanded(flex: 10, child: _Cell('${learner.totalAttempts} attempts')),
          SizedBox(
            width: 38,
            child: IconButton(
              tooltip: 'Open learner details',
              onPressed: onTap,
              icon: const Icon(Icons.chevron_right_rounded, size: 19),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MobileLearner extends StatelessWidget {
  const _MobileLearner({required this.learner, required this.onTap});
  final _Learner learner;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _Identity(learner)),
              StatusBadge(status: learner.accountStatus),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              _Fact('Track', learner.ieltsType),
              _Fact(
                'Band',
                '${_band(learner.currentBand)} → ${_band(learner.targetBand)}',
              ),
              _Fact(
                'Diagnostic',
                learner.diagnosticCompleted ? 'Completed' : 'Pending',
              ),
              _Fact('Last active', _relative(learner.lastActive)),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Identity extends StatelessWidget {
  const _Identity(this.learner);
  final _Learner learner;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: AdminColors.cyan.withValues(alpha: .13),
        child: Text(
          learner.initials,
          style: const TextStyle(
            color: AdminColors.cyan,
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              learner.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminColors.text,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              learner.email.isEmpty ? learner.id : learner.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AdminColors.textMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    ],
  );
}

class _BandGoal extends StatelessWidget {
  const _BandGoal(this.learner);
  final _Learner learner;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        _band(learner.currentBand),
        style: const TextStyle(
          color: AdminColors.text,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Icon(
          Icons.arrow_forward_rounded,
          color: AdminColors.textMuted,
          size: 12,
        ),
      ),
      Text(
        _band(learner.targetBand),
        style: const TextStyle(
          color: AdminColors.cyan,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    ],
  );
}

class _Diagnostic extends StatelessWidget {
  const _Diagnostic(this.completed);
  final bool completed;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        completed ? Icons.check_circle_rounded : Icons.schedule_rounded,
        color: completed ? AdminColors.success : AdminColors.warning,
        size: 15,
      ),
      const SizedBox(width: 6),
      Text(
        completed ? 'Completed' : 'Pending',
        style: TextStyle(
          color: completed ? AdminColors.success : AdminColors.warning,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _Cell extends StatelessWidget {
  const _Cell(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(color: AdminColors.textMuted, fontSize: 9.5),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 130,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AdminColors.textMuted,
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AdminColors.text,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pages,
    required this.pageSize,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSize,
  });
  final int page;
  final int pages;
  final int pageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSize;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text(
        'Rows',
        style: TextStyle(color: AdminColors.textMuted, fontSize: 10),
      ),
      const SizedBox(width: 8),
      DropdownButton<int>(
        value: pageSize,
        underline: const SizedBox.shrink(),
        items: const [
          20,
          50,
          100,
        ].map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
        onChanged: (v) {
          if (v != null) onPageSize(v);
        },
      ),
      const Spacer(),
      Text(
        'Page ${page + 1} of $pages',
        style: const TextStyle(
          color: AdminColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      IconButton(
        tooltip: 'Previous page',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      IconButton(
        tooltip: 'Next page',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

class _DetailsDialog extends StatelessWidget {
  const _DetailsDialog({required this.learner, required this.onChangeStatus});
  final _Learner learner;
  final VoidCallback onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final suspended = learner.accountStatus == 'suspended';
    final details = <Widget>[
      _Detail('IELTS type', learner.ieltsType),
      _Detail('Current estimated band', _band(learner.currentBand)),
      _Detail('Target band', _band(learner.targetBand)),
      _Detail('Exam date', _formatDate(learner.examDate)),
      _Detail('Registered', _formatDate(learner.createdAt)),
      _Detail('Last active', _formatDateTime(learner.lastActive)),
      _Detail(
        'Diagnostic',
        learner.diagnosticCompleted ? 'Completed' : 'Not completed',
      ),
      _Detail('Mock tests', '${learner.mockAttempts}'),
      _Detail('Listening attempts', '${learner.listeningAttempts}'),
      _Detail('Reading attempts', '${learner.readingAttempts}'),
      _Detail('Writing evaluations', '${learner.writingAttempts}'),
      _Detail('Speaking evaluations', '${learner.speakingAttempts}'),
      _Detail('Certificates issued', '${learner.certificates}'),
    ];
    return Dialog(
      backgroundColor: AdminColors.surface,
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 18),
              child: Row(
                children: [
                  Expanded(child: _Identity(learner)),
                  StatusBadge(status: learner.accountStatus),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Learner profile and activity',
                      style: TextStyle(
                        color: AdminColors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Stored goals, assessment progress and credential totals.',
                      style: TextStyle(
                        color: AdminColors.textMuted,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 600 ? 3 : 2;
                        const gap = 10.0;
                        final width =
                            (constraints.maxWidth - gap * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: details
                              .map((d) => SizedBox(width: width, child: d))
                              .toList(),
                        );
                      },
                    ),
                    if (learner.statusReason.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Administrative note',
                        style: TextStyle(
                          color: AdminColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AdminColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AdminColors.border),
                        ),
                        child: Text(
                          learner.statusReason,
                          style: const TextStyle(
                            color: AdminColors.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AdminColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Access changes are permission-checked and recorded.',
                      style: TextStyle(
                        color: AdminColors.textMuted,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onChangeStatus,
                    style: suspended
                        ? null
                        : OutlinedButton.styleFrom(
                            foregroundColor: AdminColors.danger,
                          ),
                    icon: Icon(
                      suspended
                          ? Icons.check_circle_outline_rounded
                          : Icons.block_rounded,
                    ),
                    label: Text(suspended ? 'Reactivate' : 'Suspend Account'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AdminColors.surfaceLight.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AdminColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AdminColors.textMuted,
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .65,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AdminColors.text,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final Object? error;
  @override
  Widget build(BuildContext context) {
    final raw = error?.toString().toLowerCase() ?? '';
    final message = raw.contains('permission-denied')
        ? 'Your administrator account cannot read learner profiles.'
        : 'Check the connection and Firestore access configuration, then try again.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AdminColors.textMuted),
        ),
      ),
    );
  }
}

class _Learner {
  const _Learner({
    required this.id,
    required this.name,
    required this.email,
    required this.accountStatus,
    required this.statusReason,
    required this.ieltsType,
    required this.currentBand,
    required this.targetBand,
    required this.examDate,
    required this.createdAt,
    required this.lastActive,
    required this.diagnosticCompleted,
    required this.listeningAttempts,
    required this.readingAttempts,
    required this.writingAttempts,
    required this.speakingAttempts,
    required this.mockAttempts,
    required this.certificates,
  });
  final String id;
  final String name;
  final String email;
  final String accountStatus;
  final String statusReason;
  final String ieltsType;
  final double currentBand;
  final double targetBand;
  final DateTime? examDate;
  final DateTime? createdAt;
  final DateTime? lastActive;
  final bool diagnosticCompleted;
  final int listeningAttempts;
  final int readingAttempts;
  final int writingAttempts;
  final int speakingAttempts;
  final int mockAttempts;
  final int certificates;

  int get totalAttempts =>
      listeningAttempts +
      readingAttempts +
      writingAttempts +
      speakingAttempts +
      mockAttempts;
  String get searchText => '$name $email $ieltsType'.toLowerCase();
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'IL';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory _Learner.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final stats = _asMap(data['practiceStats'] ?? data['practiceStatistics']);
    final targetBands = _asMap(data['targetBands']);
    final rawTrack = _text(
      data['ieltsType'] ?? data['selectedIeltsType'] ?? data['testType'],
      'Academic',
    ).toLowerCase();
    final storedStatus = _text(
      data['accountStatus'] ?? data['status'],
      'active',
    ).toLowerCase();
    return _Learner(
      id: doc.id,
      name: _text(
        data['fullName'] ?? data['name'] ?? data['displayName'],
        'IELTS Learner',
      ),
      email: _text(data['email'], ''),
      accountStatus: data['isDisabled'] == true || storedStatus == 'suspended'
          ? 'suspended'
          : 'active',
      statusReason: _text(data['statusReason'], ''),
      ieltsType: rawTrack.contains('general') ? 'General Training' : 'Academic',
      currentBand: _number(
        data['currentBand'] ?? data['estimatedBand'] ?? data['overallBand'],
      ),
      targetBand: _number(
        targetBands['overall'] ?? data['targetBand'] ?? data['goalBand'],
      ),
      examDate: _date(data['examDate'] ?? data['testDate']),
      createdAt: _date(data['createdAt'] ?? data['registrationDate']),
      lastActive: _date(
        data['lastActive'] ??
            data['lastSeen'] ??
            data['lastLoginAt'] ??
            data['updatedAt'],
      ),
      diagnosticCompleted:
          data['diagnosticCompleted'] == true ||
          _text(data['diagnosticStatus'], '').toLowerCase() == 'completed' ||
          _number(data['diagnosticBand']) > 0,
      listeningAttempts: _int(
        stats['listening'] ??
            data['listeningAttempts'] ??
            data['listeningCount'],
      ),
      readingAttempts: _int(
        stats['reading'] ?? data['readingAttempts'] ?? data['readingCount'],
      ),
      writingAttempts: _int(
        stats['writing'] ?? data['writingEvaluations'] ?? data['writingCount'],
      ),
      speakingAttempts: _int(
        stats['speaking'] ??
            data['speakingEvaluations'] ??
            data['speakingCount'],
      ),
      mockAttempts: _int(
        stats['mockTests'] ??
            data['mockTestsCompleted'] ??
            data['mockAttemptCount'],
      ),
      certificates: _int(
        data['certificateCount'] ?? data['certificatesIssued'],
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
String _text(dynamic value, String fallback) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

double _number(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
int _int(dynamic value) => _number(value).round();
DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

int _dateValue(DateTime? value) => value?.millisecondsSinceEpoch ?? 0;
String _band(double value) => value <= 0 ? '—' : value.toStringAsFixed(1);
String _formatDate(DateTime? value) {
  if (value == null) return 'Not set';
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'No activity recorded';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '${_formatDate(value)}, $hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String _relative(DateTime? value) {
  if (value == null) return 'Not recorded';
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 2) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 30) return '${difference.inDays}d ago';
  return _formatDate(value);
}
