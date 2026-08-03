import 'package:flutter/material.dart';
import '../data/profile_repository.dart';
import '../models/profile_model.dart';
import 'profile_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfileModel profile;

  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _repository = ProfileRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late String _ieltsType, _educationLevel;
  late double _targetBand;
  DateTime? _examDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    const ieltsTypes = {'Academic', 'General Training'};
    const educationLevels = {
      'School',
      'College',
      'University',
      'Graduate',
      'Professional',
    };

    _ieltsType = ieltsTypes.contains(widget.profile.ieltsType)
        ? widget.profile.ieltsType
        : 'Academic';
    _educationLevel = educationLevels.contains(widget.profile.educationLevel)
        ? widget.profile.educationLevel
        : 'University';
    _targetBand = _normaliseBand(widget.profile.targetBand);
    _examDate = widget.profile.examDate;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    try {
      await _repository.updateProfile(
        name: _name.text,
        ieltsType: _ieltsType,
        targetBand: _targetBand,
        examDate: _examDate,
        educationLevel: _educationLevel,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static double _normaliseBand(double value) {
    final clamped = value.clamp(4.0, 9.0).toDouble();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileColors.background,
      appBar: AppBar(
        backgroundColor: ProfileColors.background,
        title: const Text('Edit Profile'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            TextFormField(
              controller: _name,
              style: const TextStyle(color: ProfileColors.text),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) =>
                  (value ?? '').trim().length < 2 ? 'Enter your name.' : null,
            ),
            const SizedBox(height: 13),
            DropdownButtonFormField<String>(
              value: _ieltsType,
              decoration: const InputDecoration(
                labelText: 'IELTS Type',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'Academic', child: Text('Academic')),
                DropdownMenuItem(
                  value: 'General Training',
                  child: Text('General Training'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _ieltsType = value ?? _ieltsType),
            ),
            const SizedBox(height: 13),
            DropdownButtonFormField<double>(
              value: _targetBand,
              decoration: const InputDecoration(
                labelText: 'Target Band',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: [
                for (double value = 4; value <= 9; value += .5)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value.toStringAsFixed(1)),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _targetBand = value ?? _targetBand),
            ),
            const SizedBox(height: 13),
            ListTile(
              tileColor: ProfileColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text(
                'Exam Date',
                style: TextStyle(color: ProfileColors.text),
              ),
              subtitle: Text(
                _examDate == null
                    ? 'Not selected'
                    : '${_examDate!.day}/${_examDate!.month}/${_examDate!.year}',
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _pickerInitialDate(),
                  firstDate: _today(),
                  lastDate: _today().add(const Duration(days: 3650)),
                );
                if (date != null) setState(() => _examDate = date);
              },
            ),
            const SizedBox(height: 13),
            DropdownButtonFormField<String>(
              value: _educationLevel,
              decoration: const InputDecoration(
                labelText: 'Education Level',
                prefixIcon: Icon(Icons.workspace_premium_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'School', child: Text('School')),
                DropdownMenuItem(value: 'College', child: Text('College')),
                DropdownMenuItem(
                  value: 'University',
                  child: Text('University'),
                ),
                DropdownMenuItem(value: 'Graduate', child: Text('Graduate')),
                DropdownMenuItem(
                  value: 'Professional',
                  child: Text('Professional'),
                ),
              ],
              onChanged: (value) => setState(
                () => _educationLevel = value ?? _educationLevel,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Changes'),
            ),
          ),
        ),
      ),
    );
  }
}
