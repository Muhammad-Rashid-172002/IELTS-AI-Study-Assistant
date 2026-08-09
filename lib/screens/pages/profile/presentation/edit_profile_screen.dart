import 'package:flutter/material.dart';

import '../data/profile_repository.dart';
import '../models/profile_model.dart';
import 'profile_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfileModel profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  late String _ieltsType;
  late String _educationLevel;
  late double _targetBand;

  DateTime? _examDate;
  bool _saving = false;

  static const List<String> _ieltsTypes = <String>[
    'Academic',
    'General Training',
  ];

  static const List<String> _educationLevels = <String>[
    'School',
    'College',
    'University',
    'Graduate',
    'Professional',
  ];

  static const List<double> _targetBands = <double>[
    4.0,
    4.5,
    5.0,
    5.5,
    6.0,
    6.5,
    7.0,
    7.5,
    8.0,
    8.5,
    9.0,
  ];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.profile.name.trim());

    _ieltsType = _ieltsTypes.contains(widget.profile.ieltsType)
        ? widget.profile.ieltsType
        : 'Academic';

    _educationLevel = _educationLevels.contains(widget.profile.educationLevel)
        ? widget.profile.educationLevel
        : 'University';

    _targetBand = _normaliseBand(widget.profile.targetBand);
    _examDate = widget.profile.examDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _saving) return;

    setState(() => _saving = true);

    try {
      await _repository.updateProfile(
        name: _nameController.text.trim(),
        ieltsType: _ieltsType,
        targetBand: _targetBand,
        examDate: _examDate,
        educationLevel: _educationLevel,
      );

      if (!mounted) return;

      _showProfessionalSnackBar(
        title: 'Profile updated',
        message: 'Your IELTS profile changes were saved successfully.',
        type: _ProfileSnackType.success,
      );

      await Future<void>.delayed(const Duration(milliseconds: 550));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;

      _showProfessionalSnackBar(
        title: 'Could not save changes',
        message:
            'We could not update your profile right now. Please check your connection and try again.',
        type: _ProfileSnackType.error,
      );

      debugPrint('EditProfile save failed: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickExamDate() async {
    FocusScope.of(context).unfocus();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _pickerInitialDate(),
      firstDate: _today(),
      lastDate: _today().add(const Duration(days: 3650)),
      helpText: 'Select your IELTS exam date',
      cancelText: 'Cancel',
      confirmText: 'Select date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: ProfileColors.primary,
              brightness: Brightness.dark,
              surface: ProfileColors.surface,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: ProfileColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null && mounted) {
      setState(() => _examDate = selectedDate);
    }
  }

  void _clearExamDate() {
    setState(() => _examDate = null);
  }

  void _showProfessionalSnackBar({
    required String title,
    required String message,
    required _ProfileSnackType type,
  }) {
    if (!mounted) return;

    final config = _profileSnackConfig(type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          padding: EdgeInsets.zero,
          duration: const Duration(seconds: 4),
          content: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
            decoration: BoxDecoration(
              color: ProfileColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: config.color.withOpacity(.40)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.30),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: config.color.withOpacity(.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(config.icon, color: config.color, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ProfileColors.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          color: ProfileColors.text.withOpacity(.68),
                          fontSize: 10.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: ProfileColors.text.withOpacity(.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  static double _normaliseBand(double value) {
    final double clamped = value.clamp(4.0, 9.0).toDouble();
    return (clamped * 2).round() / 2;
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _pickerInitialDate() {
    final today = _today();
    final selected = _examDate;

    if (selected == null || selected.isBefore(today)) {
      return today.add(const Duration(days: 90));
    }

    return selected;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No exam date selected';

    const months = <String>[
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

  int? _daysUntilExam() {
    if (_examDate == null) return null;

    final difference = _examDate!.difference(_today()).inDays;
    return difference < 0 ? 0 : difference;
  }

  @override
  Widget build(BuildContext context) {
    final daysUntilExam = _daysUntilExam();

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: ProfileColors.background,
        body: Stack(
          children: [
            const Positioned.fill(child: _ProfileEditBackground()),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _ProfessionalHeader(
                    saving: _saving,
                    onBack: () {
                      if (!_saving) Navigator.pop(context);
                    },
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 130),
                        children: [
                          _ProfileHeroCard(
                            name: _nameController.text.trim().isEmpty
                                ? 'IELTS Learner'
                                : _nameController.text.trim(),
                            targetBand: _targetBand,
                            ieltsType: _ieltsType,
                            educationLevel: _educationLevel,
                            examDate: _examDate,
                          ),
                          const SizedBox(height: 20),
                          const _SectionHeader(
                            title: 'Personal Information',
                            subtitle:
                                'Keep your learner profile accurate and up to date.',
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 11),
                          _FormCard(
                            child: TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(
                                color: ProfileColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                              onChanged: (_) => setState(() {}),
                              decoration: _inputDecoration(
                                label: 'Full Name',
                                hint: 'Enter your full name',
                                icon: Icons.person_outline_rounded,
                              ),
                              validator: (value) {
                                final text = (value ?? '').trim();

                                if (text.isEmpty) {
                                  return 'Please enter your full name.';
                                }

                                if (text.length < 2) {
                                  return 'Name must contain at least 2 characters.';
                                }

                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _SectionHeader(
                            title: 'IELTS Preferences',
                            subtitle:
                                'Personalize your study experience and target score.',
                            icon: Icons.school_outlined,
                          ),
                          const SizedBox(height: 11),
                          _FormCard(
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _ieltsType,
                                  dropdownColor: ProfileColors.surface,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  decoration: _inputDecoration(
                                    label: 'IELTS Type',
                                    hint: 'Choose your IELTS test type',
                                    icon: Icons.school_outlined,
                                  ),
                                  items: _ieltsTypes
                                      .map(
                                        (value) => DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(
                                            value,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _saving
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setState(() => _ieltsType = value);
                                        },
                                ),
                                const SizedBox(height: 13),
                                DropdownButtonFormField<double>(
                                  value: _targetBand,
                                  dropdownColor: ProfileColors.surface,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  decoration: _inputDecoration(
                                    label: 'Target Band',
                                    hint: 'Select your target band',
                                    icon: Icons.flag_outlined,
                                  ),
                                  items: _targetBands
                                      .map(
                                        (value) => DropdownMenuItem<double>(
                                          value: value,
                                          child: Row(
                                            children: [
                                              Text(
                                                'Band ${value.toStringAsFixed(1)}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const Spacer(),
                                              _BandPill(value: value),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _saving
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          setState(() => _targetBand = value);
                                        },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _SectionHeader(
                            title: 'Exam Planning',
                            subtitle:
                                'Set your exam date so your study plan can stay focused.',
                            icon: Icons.calendar_month_outlined,
                          ),
                          const SizedBox(height: 11),
                          _ExamDateCard(
                            examDate: _examDate,
                            formattedDate: _formatDate(_examDate),
                            daysUntilExam: daysUntilExam,
                            onTap: _saving ? null : _pickExamDate,
                            onClear: _saving || _examDate == null
                                ? null
                                : _clearExamDate,
                          ),
                          const SizedBox(height: 20),
                          const _SectionHeader(
                            title: 'Education',
                            subtitle:
                                'Help tailor recommendations to your current academic level.',
                            icon: Icons.account_balance_outlined,
                          ),
                          const SizedBox(height: 11),
                          _FormCard(
                            child: DropdownButtonFormField<String>(
                              value: _educationLevel,
                              dropdownColor: ProfileColors.surface,

                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),

                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                              ),

                              decoration: _inputDecoration(
                                label: 'Education Level',
                                hint: 'Select your education level',
                                icon: Icons.workspace_premium_outlined,
                              ),

                              items: _educationLevels
                                  .map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),

                              onChanged: _saving
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setState(() => _educationLevel = value);
                                    },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PrivacyNotice(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _SaveBar(saving: _saving, onSave: _save),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: ProfileColors.background.withOpacity(.42),
      labelStyle: TextStyle(
        color: ProfileColors.text.withOpacity(.72),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(
        color: ProfileColors.text.withOpacity(.35),
        fontSize: 10.5,
      ),
      prefixIconColor: ProfileColors.primary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(.07)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(.07)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ProfileColors.primary, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    );
  }
}

class _ProfessionalHeader extends StatelessWidget {
  final bool saving;
  final VoidCallback onBack;

  const _ProfessionalHeader({required this.saving, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 18, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: saving ? null : onBack,
            style: IconButton.styleFrom(
              backgroundColor: ProfileColors.surface,
              foregroundColor: ProfileColors.text,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: ProfileColors.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.35,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Personalize your IELTS learning experience',
                  style: TextStyle(color: Colors.white54, fontSize: 9.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: ProfileColors.primary.withOpacity(.10),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: ProfileColors.primary.withOpacity(.22)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: ProfileColors.primary,
                ),
                SizedBox(width: 5),
                Text(
                  'PROFILE',
                  style: TextStyle(
                    color: ProfileColors.primary,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
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

class _ProfileHeroCard extends StatelessWidget {
  final String name;
  final double targetBand;
  final String ieltsType;
  final String educationLevel;
  final DateTime? examDate;

  const _ProfileHeroCard({
    required this.name,
    required this.targetBand,
    required this.ieltsType,
    required this.educationLevel,
    required this.examDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ProfileColors.primary.withOpacity(.22),
            ProfileColors.surface,
            const Color(0xFF7C3AED).withOpacity(.15),
          ],
        ),
        border: Border.all(color: ProfileColors.primary.withOpacity(.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.20),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ProfileColors.primary, const Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ProfileColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$ieltsType • $educationLevel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ProfileColors.text.withOpacity(.56),
                        fontSize: 9.8,
                      ),
                    ),
                  ],
                ),
              ),
              _TargetBandCircle(band: targetBand),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  icon: Icons.flag_outlined,
                  label: 'Target',
                  value: targetBand.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.school_outlined,
                  label: 'IELTS Type',
                  value: ieltsType == 'General Training'
                      ? 'General'
                      : ieltsType,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroMetric(
                  icon: Icons.event_outlined,
                  label: 'Exam',
                  value: examDate == null
                      ? 'Not set'
                      : '${examDate!.day}/${examDate!.month}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TargetBandCircle extends StatelessWidget {
  final double band;

  const _TargetBandCircle({required this.band});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(.18),
        border: Border.all(color: ProfileColors.primary.withOpacity(.32)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            band.toStringAsFixed(1),
            style: const TextStyle(
              color: ProfileColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'TARGET',
            style: TextStyle(
              color: ProfileColors.text.withOpacity(.42),
              fontSize: 6.2,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: ProfileColors.primary, size: 17),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ProfileColors.text,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ProfileColors.text.withOpacity(.40),
              fontSize: 7.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: ProfileColors.primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ProfileColors.primary.withOpacity(.18)),
          ),
          child: Icon(icon, color: ProfileColors.primary, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ProfileColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: ProfileColors.text.withOpacity(.42),
                  fontSize: 8.8,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ProfileColors.surface.withOpacity(.94),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.white.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.14),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ExamDateCard extends StatelessWidget {
  final DateTime? examDate;
  final String formattedDate;
  final int? daysUntilExam;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _ExamDateCard({
    required this.examDate,
    required this.formattedDate,
    required this.daysUntilExam,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: ProfileColors.surface.withOpacity(.94),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: examDate == null
                  ? Colors.white.withOpacity(.06)
                  : ProfileColors.primary.withOpacity(.23),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: ProfileColors.primary.withOpacity(.11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: ProfileColors.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IELTS Exam Date',
                      style: TextStyle(
                        color: ProfileColors.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: ProfileColors.text.withOpacity(.60),
                        fontSize: 10,
                      ),
                    ),
                    if (daysUntilExam != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        daysUntilExam == 0
                            ? 'Exam day'
                            : '$daysUntilExam days remaining',
                        style: const TextStyle(
                          color: ProfileColors.primary,
                          fontSize: 8.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (examDate != null && onClear != null)
                IconButton(
                  tooltip: 'Clear exam date',
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: ProfileColors.text.withOpacity(.42),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: ProfileColors.text.withOpacity(.35),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BandPill extends StatelessWidget {
  final double value;

  const _BandPill({required this.value});

  @override
  Widget build(BuildContext context) {
    final label = value >= 8
        ? 'Advanced'
        : value >= 7
        ? 'Strong'
        : value >= 6
        ? 'Competent'
        : 'Developing';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: ProfileColors.primary.withOpacity(.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: ProfileColors.primary,
          fontSize: 7.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ProfileColors.primary.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProfileColors.primary.withOpacity(.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: ProfileColors.primary,
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Your profile information is used to personalize your IELTS targets, study recommendations and exam planning.',
              style: TextStyle(
                color: ProfileColors.text.withOpacity(.52),
                fontSize: 8.8,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;

  const _SaveBar({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ProfileColors.background.withOpacity(.96),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.30),
            blurRadius: 26,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
          child: SizedBox(
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ProfileColors.primary, const Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: ProfileColors.primary.withOpacity(.22),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  saving ? 'Saving changes...' : 'Save Changes',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileEditBackground extends StatelessWidget {
  const _ProfileEditBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ProfileColors.primary.withOpacity(.08),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -110,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C3AED).withOpacity(.06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ProfileSnackType { success, error }

class _ProfileSnackConfig {
  final Color color;
  final IconData icon;

  const _ProfileSnackConfig({required this.color, required this.icon});
}

_ProfileSnackConfig _profileSnackConfig(_ProfileSnackType type) {
  switch (type) {
    case _ProfileSnackType.success:
      return const _ProfileSnackConfig(
        color: Color(0xFF22C55E),
        icon: Icons.check_circle_rounded,
      );
    case _ProfileSnackType.error:
      return const _ProfileSnackConfig(
        color: Colors.redAccent,
        icon: Icons.error_rounded,
      );
  }
}
