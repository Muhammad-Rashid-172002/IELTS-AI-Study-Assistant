import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/9-step%20premium%20profile%20setup%20wizard/diagnotics_intro_screen.dart';

class InitialProfileSetupScreen extends StatefulWidget {
  const InitialProfileSetupScreen({super.key});

  @override
  State<InitialProfileSetupScreen> createState() =>
      _InitialProfileSetupScreenState();
}

class _InitialProfileSetupScreenState extends State<InitialProfileSetupScreen> {
  final PageController _pageController = PageController();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _customStudyTimeController =
      TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _currentStep = 0;
  bool _isSaving = false;

  String _ageRange = '18–24';
  String _gender = 'Prefer not to say';
  String _country = 'Pakistan';
  String _nativeLanguage = 'Urdu';
  String _preferredLanguage = 'English';

  String _educationLevel = 'Bachelor';
  String _ieltsPurpose = 'Master admission';
  String _destination = 'United Kingdom';
  String _ieltsType = 'Academic';
  String _currentLevel = 'Not sure';

  double _overallTarget = 7.0;
  double _listeningTarget = 7.0;
  double _readingTarget = 7.0;
  double _writingTarget = 6.5;
  double _speakingTarget = 6.5;

  String _examDateOption = 'No date selected';
  DateTime? _exactExamDate;

  String _dailyStudyTime = '45 minutes';

  final List<String> _ageRanges = const [
    'Under 18',
    '18–24',
    '25–34',
    '35–44',
    '45+',
  ];

  final List<String> _genders = const ['Male', 'Female', 'Prefer not to say'];

  final List<String> _countries = const [
    'Pakistan',
    'United Kingdom',
    'Australia',
    'Canada',
    'New Zealand',
    'United States',
    'United Arab Emirates',
    'Saudi Arabia',
    'India',
    'Bangladesh',
    'China',
    'Other',
  ];

  final List<String> _languages = const [
    'English',
    'Urdu',
    'Arabic',
    'Hindi',
    'Spanish',
    'Chinese',
    'Other',
  ];

  final List<String> _educationLevels = const [
    'School',
    'Intermediate / College',
    'Bachelor',
    'Master',
    'PhD',
    'Working Professional',
    'Other',
  ];
  final List<IconData> _educationIcons = const [
    Icons.school_outlined,
    Icons.account_balance_outlined,
    Icons.workspace_premium_outlined,
    Icons.menu_book_rounded,
    Icons.science_outlined,
    Icons.business_center_outlined,
    Icons.more_horiz_rounded,
  ];
  final List<String> _educationSubtitles = const [
    'Primary or secondary education',
    'Higher secondary education',
    'Undergraduate degree',
    'Postgraduate degree',
    'Doctoral studies',
    'Currently employed',
    'Different background',
  ];

  final List<String> _purposes = const [
    'Bachelor admission',
    'Master admission',
    'PhD admission',
    'Immigration',
    'Employment',
    'Professional registration',
    'Personal improvement',
  ];

  final List<String> _destinations = const [
    'United Kingdom',
    'Australia',
    'Canada',
    'New Zealand',
    'United States',
    'Europe',
    'Other',
  ];
  final List<String> _destinationFlags = const [
    '🇬🇧',
    '🇦🇺',
    '🇨🇦',
    '🇳🇿',
    '🇺🇸',
    '🇪🇺',
    '🌍',
  ];

  final List<String> _currentLevels = const [
    'I have never taken IELTS',
    'Below Band 4',
    'Band 4–5',
    'Band 5–6',
    'Band 6–7',
    'Band 7+',
    'Not sure',
  ];

  final List<String> _examDateOptions = const [
    'Exact date',
    'Planning within 1 month',
    '1–3 months',
    '3–6 months',
    'No date selected',
  ];

  final List<String> _studyTimes = const [
    '15 minutes',
    '30 minutes',
    '45 minutes',
    '60 minutes',
    '90 minutes',
    'Custom',
  ];
  final List<IconData> _studyTimeIcons = const [
    Icons.timer_outlined,
    Icons.schedule_outlined,
    Icons.av_timer_rounded,
    Icons.access_time_rounded,
    Icons.hourglass_bottom_rounded,
    Icons.tune_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fullNameController.text = _auth.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _customStudyTimeController.dispose();
    super.dispose();
  }

  bool get _isLastStep => _currentStep == 8;

  Future<void> _nextStep() async {
    if (!_validateCurrentStep()) return;

    if (_isLastStep) {
      setState(() => _isSaving = true);

      try {
        await _saveProfile();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DiagnosticIntroScreen(
              ieltsType: 'Academic',
              targetBand: 7.0,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Profile save error: $e');
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }

      return;
    }

    setState(() {
      _currentStep++;
    });

    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _previousStep() async {
    if (_currentStep == 0) {
      Navigator.maybePop(context);
      return;
    }

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0 && _fullNameController.text.trim().length < 3) {
      _showMessage('Please enter your complete name.');
      return false;
    }

    if (_currentStep == 7 &&
        _examDateOption == 'Exact date' &&
        _exactExamDate == null) {
      _showMessage('Please choose your IELTS exam date.');
      return false;
    }

    if (_currentStep == 8 &&
        _dailyStudyTime == 'Custom' &&
        _customStudyTimeController.text.trim().isEmpty) {
      _showMessage('Enter your custom daily study time.');
      return false;
    }

    return true;
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please sign in again before saving your profile.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dailyStudyMinutes = _resolveStudyMinutes();

      await user.updateDisplayName(_fullNameController.text.trim());

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': _fullNameController.text.trim(),
        'email': user.email,
        'ageRange': _ageRange,
        'gender': _gender,
        'country': _country,
        'nativeLanguage': _nativeLanguage,
        'preferredAppLanguage': _preferredLanguage,
        'educationLevel': _educationLevel,
        'ieltsPurpose': _ieltsPurpose,
        'destination': _destination,
        'ieltsType': _ieltsType,
        'currentLevel': _currentLevel,
        'targetBands': {
          'overall': _overallTarget,
          'listening': _listeningTarget,
          'reading': _readingTarget,
          'writing': _writingTarget,
          'speaking': _speakingTarget,
        },
        'examDatePreference': _examDateOption,
        'exactExamDate': _exactExamDate == null
            ? null
            : Timestamp.fromDate(_exactExamDate!),
        'dailyStudyTimeLabel': _dailyStudyTime,
        'dailyStudyMinutes': dailyStudyMinutes,
        'profileCompleted': true,
        'profileCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProfileSetupCompleteScreen()),
      );
    } catch (error) {
      _showMessage('Profile could not be saved. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  int _resolveStudyMinutes() {
    switch (_dailyStudyTime) {
      case '15 minutes':
        return 15;
      case '30 minutes':
        return 30;
      case '45 minutes':
        return 45;
      case '60 minutes':
        return 60;
      case '90 minutes':
        return 90;
      case 'Custom':
        return int.tryParse(_customStudyTimeController.text.trim()) ?? 45;
      default:
        return 45;
    }
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _exactExamDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ProfileColors.cyan,
              onPrimary: ProfileColors.background,
              surface: ProfileColors.surface,
              onSurface: ProfileColors.mainText,
            ),
            dialogBackgroundColor: ProfileColors.surface,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() => _exactExamDate = pickedDate);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ProfileColors.surfaceLight,
          content: Text(text),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _ProfileBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentStep = index);
                    },
                    children: [
                      _buildBasicInformationStep(),
                      _buildEducationStep(),
                      _buildPurposeStep(),
                      _buildDestinationStep(),
                      _buildIELTSTypeStep(),
                      _buildCurrentLevelStep(),
                      _buildTargetBandStep(),
                      _buildExamDateStep(),
                      _buildStudyTimeStep(),
                    ],
                  ),
                ),
                _buildBottomNavigation(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final titles = [
      'Basic Information',
      'Education Level',
      'IELTS Purpose',
      'Destination',
      'IELTS Type',
      'Current Level',
      'Target Band',
      'Exam Date',
      'Daily Study Time',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _previousStep,
                style: IconButton.styleFrom(
                  backgroundColor: ProfileColors.surface,
                  foregroundColor: ProfileColors.mainText,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titles[_currentStep],
                      style: const TextStyle(
                        color: ProfileColors.mainText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Step ${_currentStep + 1} of 9',
                      style: const TextStyle(
                        color: ProfileColors.mutedText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: ProfileColors.gradient,
                ),
                child: Text(
                  '${_currentStep + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 9,
              minHeight: 7,
              backgroundColor: ProfileColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                ProfileColors.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInformationStep() {
    return _StepContainer(
      title: 'Tell us about yourself',
      description:
          'This helps us personalize your IELTS experience and app instructions.',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          _ProfileTextField(
            controller: _fullNameController,
            label: 'Full name',
            hint: 'Enter your complete name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          _ProfileDropdown(
            label: 'Age range',
            icon: Icons.cake_outlined,
            value: _ageRange,
            items: _ageRanges,
            onChanged: (value) {
              if (value != null) {
                setState(() => _ageRange = value);
              }
            },
          ),
          const SizedBox(height: 14),
          _ProfileDropdown(
            label: 'Gender (optional)',
            icon: Icons.wc_rounded,
            value: _gender,
            items: _genders,
            onChanged: (value) {
              if (value != null) {
                setState(() => _gender = value);
              }
            },
          ),
          const SizedBox(height: 14),
          _ProfileDropdown(
            label: 'Country',
            icon: Icons.public_rounded,
            value: _country,
            items: _countries,
            onChanged: (value) {
              if (value != null) {
                setState(() => _country = value);
              }
            },
          ),
          const SizedBox(height: 14),
          _ProfileDropdown(
            label: 'Native language',
            icon: Icons.translate_rounded,
            value: _nativeLanguage,
            items: _languages,
            onChanged: (value) {
              if (value != null) {
                setState(() => _nativeLanguage = value);
              }
            },
          ),
          const SizedBox(height: 14),
          _ProfileDropdown(
            label: 'Preferred app language',
            icon: Icons.language_rounded,
            value: _preferredLanguage,
            items: _languages,
            onChanged: (value) {
              if (value != null) {
                setState(() => _preferredLanguage = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEducationStep() {
    return _StepContainer(
      title: 'What is your education level?',
      description:
          'We use this only to select relevant topics and vocabulary context. It does not directly decide IELTS difficulty.',
      icon: Icons.school_outlined,
      child: _SelectionGrid(
        options: _educationLevels,
        selectedValue: _educationLevel,
        icons: _educationIcons,
        subtitles: _educationSubtitles,
        onSelected: (value) {
          setState(() => _educationLevel = value);
        },
      ),
    );
  }

  Widget _buildPurposeStep() {
    return _StepContainer(
      title: 'Why are you preparing for IELTS?',
      description:
          'Your purpose helps us recommend the most suitable test type and preparation path.',
      icon: Icons.flag_outlined,
      child: _SelectionList(
        options: _purposes,
        selectedValue: _ieltsPurpose,
        icons: const [
          Icons.school_outlined,
          Icons.workspace_premium_outlined,
          Icons.science_outlined,
          Icons.flight_takeoff_rounded,
          Icons.work_outline_rounded,
          Icons.badge_outlined,
          Icons.trending_up_rounded,
        ],
        onSelected: (value) {
          setState(() => _ieltsPurpose = value);
        },
      ),
    );
  }

  Widget _buildDestinationStep() {
    return _StepContainer(
      title: 'Where are you planning to go?',
      description:
          'This helps us organize country-relevant guidance and your preparation goal.',
      icon: Icons.travel_explore_rounded,
      child: _SelectionGrid(
        options: _destinations,
        selectedValue: _destination,
        emojis: _destinationFlags,
        onSelected: (value) {
          setState(() => _destination = value);
        },
      ),
    );
  }

  Widget _buildIELTSTypeStep() {
    return _StepContainer(
      title: 'Choose your IELTS test type',
      description: 'You can change this later from your profile settings.',
      icon: Icons.fact_check_outlined,
      child: Column(
        children: [
          _IELTSTypeCard(
            title: 'IELTS Academic',
            description: 'For higher education and professional registration.',
            icon: Icons.account_balance_outlined,
            selected: _ieltsType == 'Academic',
            badge:
                _ieltsPurpose.contains('admission') ||
                    _ieltsPurpose == 'Professional registration'
                ? 'Recommended'
                : null,
            onTap: () {
              setState(() => _ieltsType = 'Academic');
            },
          ),
          const SizedBox(height: 14),
          _IELTSTypeCard(
            title: 'IELTS General Training',
            description: 'For immigration, work and everyday English contexts.',
            icon: Icons.public_rounded,
            selected: _ieltsType == 'General Training',
            badge:
                _ieltsPurpose == 'Immigration' || _ieltsPurpose == 'Employment'
                ? 'Recommended'
                : null,
            onTap: () {
              setState(() => _ieltsType = 'General Training');
            },
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            text:
                'Listening and Speaking follow the same general format, while Reading and Writing differ between Academic and General Training.',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLevelStep() {
    return _StepContainer(
      title: 'What is your current IELTS level?',
      description:
          'Choose your closest estimate. The diagnostic test will calculate a more accurate starting level.',
      icon: Icons.insights_outlined,
      child: _SelectionList(
        options: _currentLevels,
        selectedValue: _currentLevel,
        icons: const [
          Icons.new_releases_outlined,
          Icons.looks_one_outlined,
          Icons.looks_4_outlined,
          Icons.looks_5_outlined,
          Icons.looks_6_outlined,
          Icons.star_outline_rounded,
          Icons.help_outline_rounded,
        ],
        onSelected: (value) {
          setState(() => _currentLevel = value);
        },
      ),
    );
  }

  Widget _buildTargetBandStep() {
    return _StepContainer(
      title: 'Set your target bands',
      description: 'Choose an overall target and individual skill goals.',
      icon: Icons.track_changes_rounded,
      child: Column(
        children: [
          _BandSlider(
            title: 'Overall target',
            value: _overallTarget,
            accent: ProfileColors.cyan,
            onChanged: (value) {
              setState(() => _overallTarget = value);
            },
          ),
          const SizedBox(height: 12),
          _BandSlider(
            title: 'Listening target',
            value: _listeningTarget,
            accent: const Color(0xFF38BDF8),
            onChanged: (value) {
              setState(() => _listeningTarget = value);
            },
          ),
          const SizedBox(height: 12),
          _BandSlider(
            title: 'Reading target',
            value: _readingTarget,
            accent: const Color(0xFF60A5FA),
            onChanged: (value) {
              setState(() => _readingTarget = value);
            },
          ),
          const SizedBox(height: 12),
          _BandSlider(
            title: 'Writing target',
            value: _writingTarget,
            accent: const Color(0xFFA78BFA),
            onChanged: (value) {
              setState(() => _writingTarget = value);
            },
          ),
          const SizedBox(height: 12),
          _BandSlider(
            title: 'Speaking target',
            value: _speakingTarget,
            accent: const Color(0xFF34D399),
            onChanged: (value) {
              setState(() => _speakingTarget = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExamDateStep() {
    return _StepContainer(
      title: 'When is your IELTS exam?',
      description:
          'We will use this to organize your study intensity and exam countdown.',
      icon: Icons.event_available_outlined,
      child: Column(
        children: [
          _SelectionList(
            options: _examDateOptions,
            selectedValue: _examDateOption,
            icons: const [
              Icons.calendar_month_outlined,
              Icons.looks_one_outlined,
              Icons.date_range_outlined,
              Icons.calendar_view_month_outlined,
              Icons.event_busy_outlined,
            ],
            onSelected: (value) {
              setState(() {
                _examDateOption = value;
                if (value != 'Exact date') {
                  _exactExamDate = null;
                }
              });
            },
          ),
          if (_examDateOption == 'Exact date') ...[
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickExamDate,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ProfileColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: ProfileColors.cyan.withOpacity(0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: ProfileColors.cyan,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _exactExamDate == null
                              ? 'Choose exact exam date'
                              : '${_exactExamDate!.day}/${_exactExamDate!.month}/${_exactExamDate!.year}',
                          style: const TextStyle(
                            color: ProfileColors.mainText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: ProfileColors.mutedText,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyTimeStep() {
    return _StepContainer(
      title: 'How much time can you study daily?',
      description: 'Your daily plan will fit within this available study time.',
      icon: Icons.schedule_rounded,
      child: Column(
        children: [
          _SelectionGrid(
            options: _studyTimes,
            selectedValue: _dailyStudyTime,
            icons: _studyTimeIcons,
            onSelected: (value) {
              setState(() => _dailyStudyTime = value);
            },
          ),
          if (_dailyStudyTime == 'Custom') ...[
            const SizedBox(height: 16),
            _ProfileTextField(
              controller: _customStudyTimeController,
              label: 'Custom minutes',
              hint: 'Example: 75',
              icon: Icons.edit_calendar_outlined,
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 18),
          _ProfileSummaryCard(
            ieltsType: _ieltsType,
            targetBand: _overallTarget,
            destination: _destination,
            studyTime: _dailyStudyTime == 'Custom'
                ? '${_customStudyTimeController.text.trim()} minutes'
                : _dailyStudyTime,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: ProfileColors.background.withOpacity(0.96),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ProfileColors.mainText,
                    side: BorderSide(color: Colors.white.withOpacity(0.09)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  gradient: ProfileColors.gradient,
                  boxShadow: [
                    BoxShadow(
                      color: ProfileColors.blue.withOpacity(0.25),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLastStep ? 'Complete Profile' : 'Continue',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _isLastStep
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 20,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepContainer extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Widget child;

  const _StepContainer({
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ProfileColors.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: ProfileColors.gradient,
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ProfileColors.mainText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          color: ProfileColors.mutedText,
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SelectionGrid extends StatelessWidget {
  final List<String> options;
  final String selectedValue;
  final List<IconData>? icons;
  final List<String>? subtitles;
  final ValueChanged<String> onSelected;
  final List<String>? emojis;
  final double childAspectRatio;

  const _SelectionGrid({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.icons,
    this.subtitles,
    this.emojis,
    this.childAspectRatio = 1.15,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: options.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final option = options[index];
        final selected = option == selectedValue;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelected(option),
            borderRadius: BorderRadius.circular(19),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF13304A)
                    : ProfileColors.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: selected
                      ? ProfileColors.cyan.withOpacity(0.70)
                      : Colors.white.withOpacity(0.065),
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: ProfileColors.cyan.withOpacity(0.16),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: selected
                              ? ProfileColors.cyan.withOpacity(0.14)
                              : ProfileColors.surfaceLight,
                          border: Border.all(
                            color: selected
                                ? ProfileColors.cyan.withOpacity(0.30)
                                : Colors.white.withOpacity(0.04),
                          ),
                        ),
                        child: Center(
                          child: emojis != null && index < emojis!.length
                              ? Text(
                                  emojis![index],
                                  style: const TextStyle(fontSize: 27),
                                )
                              : Icon(
                                  icons != null && index < icons!.length
                                      ? icons![index]
                                      : Icons.public_rounded,
                                  color: selected
                                      ? Colors.white
                                      : ProfileColors.mutedText,
                                  size: 24,
                                ),
                        ),
                      ),

                      Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? ProfileColors.cyan
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? ProfileColors.cyan
                                : ProfileColors.border,
                            width: 1.2,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: ProfileColors.background,
                                size: 17,
                              )
                            : null,
                      ),
                    ],
                  ),

                  const Spacer(),

                  Text(
                    option,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ProfileColors.mainText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),

                  if (subtitles != null && index < subtitles!.length) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitles![index],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ProfileColors.mutedText,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SelectionList extends StatelessWidget {
  final List<String> options;
  final String selectedValue;
  final List<IconData> icons;
  final ValueChanged<String> onSelected;

  const _SelectionList({
    required this.options,
    required this.selectedValue,
    required this.icons,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(options.length, (index) {
        final option = options[index];
        final selected = option == selectedValue;

        return Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(option),
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF13304A)
                      : ProfileColors.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? ProfileColors.cyan.withOpacity(0.62)
                        : Colors.white.withOpacity(0.065),
                    width: selected ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? ProfileColors.cyan.withOpacity(0.14)
                            : ProfileColors.surfaceLight,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        icons[index],
                        color: selected
                            ? ProfileColors.cyan
                            : ProfileColors.mutedText,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option,
                        style: const TextStyle(
                          color: ProfileColors.mainText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? ProfileColors.cyan
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? ProfileColors.cyan
                              : ProfileColors.border,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: ProfileColors.background,
                              size: 16,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _IELTSTypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _IELTSTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF13304A)
                : ProfileColors.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? ProfileColors.cyan.withOpacity(0.65)
                  : Colors.white.withOpacity(0.065),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: selected
                      ? ProfileColors.gradient
                      : const LinearGradient(
                          colors: [Color(0xFF1A2A3F), Color(0xFF142337)],
                        ),
                ),
                child: Icon(icon, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ProfileColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Color(0xFF6EE7B7),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        color: ProfileColors.mainText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: ProfileColors.mutedText,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? ProfileColors.cyan : Colors.transparent,
                  border: Border.all(
                    color: selected ? ProfileColors.cyan : ProfileColors.border,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: ProfileColors.background,
                        size: 17,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final String title;
  final double value;
  final Color accent;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.title,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProfileColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withOpacity(0.065)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: ProfileColors.mainText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                width: 49,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              inactiveTrackColor: ProfileColors.border,
              thumbColor: accent,
              overlayColor: accent.withOpacity(0.14),
              trackHeight: 5,
            ),
            child: Slider(
              min: 4.0,
              max: 9.0,
              divisions: 10,
              value: value,
              onChanged: onChanged,
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '4.0',
                style: TextStyle(
                  color: ProfileColors.subtleText,
                  fontSize: 9.5,
                ),
              ),
              Text(
                '9.0',
                style: TextStyle(
                  color: ProfileColors.subtleText,
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

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: ProfileColors.cyan,
      style: const TextStyle(
        color: ProfileColors.mainText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: ProfileColors.mutedText,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: ProfileColors.subtleText,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: ProfileColors.mutedText, size: 21),
        filled: true,
        fillColor: ProfileColors.surface.withOpacity(0.92),
        border: _fieldBorder(ProfileColors.border),
        enabledBorder: _fieldBorder(ProfileColors.border),
        focusedBorder: _fieldBorder(ProfileColors.cyan, width: 1.4),
      ),
    );
  }
}

class _ProfileDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _ProfileDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: ProfileColors.surface,
      iconEnabledColor: ProfileColors.cyan,
      style: const TextStyle(
        color: ProfileColors.mainText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: ProfileColors.mutedText,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: ProfileColors.mutedText, size: 21),
        filled: true,
        fillColor: ProfileColors.surface.withOpacity(0.92),
        border: _fieldBorder(ProfileColors.border),
        enabledBorder: _fieldBorder(ProfileColors.border),
        focusedBorder: _fieldBorder(ProfileColors.cyan, width: 1.4),
      ),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String text;

  const _InfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ProfileColors.blue.withOpacity(0.09),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: ProfileColors.cyan.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: ProfileColors.cyan,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: ProfileColors.secondaryText,
                fontSize: 11.2,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  final String ieltsType;
  final double targetBand;
  final String destination;
  final String studyTime;

  const _ProfileSummaryCard({
    required this.ieltsType,
    required this.targetBand,
    required this.destination,
    required this.studyTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        gradient: LinearGradient(
          colors: [
            ProfileColors.blue.withOpacity(0.18),
            ProfileColors.cyan.withOpacity(0.10),
            ProfileColors.violet.withOpacity(0.13),
          ],
        ),
        border: Border.all(color: ProfileColors.cyan.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your setup summary',
            style: TextStyle(
              color: ProfileColors.mainText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          _SummaryRow(
            icon: Icons.fact_check_outlined,
            label: 'IELTS type',
            value: ieltsType,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.track_changes_rounded,
            label: 'Target band',
            value: targetBand.toStringAsFixed(1),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.flight_takeoff_rounded,
            label: 'Destination',
            value: destination,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.schedule_rounded,
            label: 'Daily study',
            value: studyTime,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ProfileColors.cyan, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: ProfileColors.mutedText,
              fontSize: 11,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: ProfileColors.mainText,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileBackground extends StatelessWidget {
  const _ProfileBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF040A13),
                Color(0xFF07111F),
                Color(0xFF09182A),
                Color(0xFF07111F),
              ],
              stops: [0, 0.35, 0.72, 1],
            ),
          ),
        ),
        const Positioned(
          top: -150,
          right: -120,
          child: _GlowOrb(size: 340, color: Color(0x2B2563EB)),
        ),
        const Positioned(
          top: 340,
          left: -160,
          child: _GlowOrb(size: 320, color: Color(0x1706B6D4)),
        ),
        const Positioned(
          bottom: -180,
          right: -150,
          child: _GlowOrb(size: 390, color: Color(0x178B5CF6)),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}

class ProfileSetupCompleteScreen extends StatelessWidget {
  const ProfileSetupCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _ProfileBackground()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(27),
                  decoration: BoxDecoration(
                    color: ProfileColors.surface.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: ProfileColors.gradient,
                          boxShadow: [
                            BoxShadow(
                              color: ProfileColors.cyan.withOpacity(0.22),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Profile setup complete',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ProfileColors.mainText,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your profile is ready. The next step will be the diagnostic IELTS assessment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ProfileColors.mutedText,
                          fontSize: 13.5,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 53,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ProfileColors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(fontWeight: FontWeight.w800),
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
    );
  }
}

class ProfileColors {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF101C2E);
  static const surfaceLight = Color(0xFF182A40);
  static const mainText = Color(0xFFF8FAFC);
  static const secondaryText = Color(0xFFCBD5E1);
  static const mutedText = Color(0xFF94A3B8);
  static const subtleText = Color(0xFF64748B);
  static const border = Color(0xFF26364A);
  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const success = Color(0xFF16A34A);

  static const gradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(17),
    borderSide: BorderSide(color: color, width: width),
  );
}
