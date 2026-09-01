import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_ai_master_admin/core/theme/admin_theme.dart';
import 'package:ielts_ai_master_admin/features/mock_test_admin_module/domain/mock_admin_models.dart';
import 'package:ielts_ai_master_admin/features/mock_test_admin_module/presentation/mock_question_details_dialog.dart';
import 'package:ielts_ai_master_admin/features/mock_test_admin_module/presentation/mock_question_editor_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'question presentation labels section and preserves editable metadata',
    () {
      final question = _listeningQuestion(status: 'approved');

      expect(question.sectionLabel, 'Section 1');
      expect(question.documentPath, 'mock_test_bank/academic/listening/q-1');

      final edited = question.copyWith(
        number: 14,
        prompt: 'Updated prompt',
        status: 'draft',
      );
      expect(edited.number, 14);
      expect(edited.prompt, 'Updated prompt');
      expect(edited.status, 'draft');
      expect(edited.correctAnswers, ['Westminster']);
      expect(edited.sourceReference, 'generation/job-1');
    },
  );

  testWidgets(
    'small-width preview exposes audio, options, answer key, and QA without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.darkTheme,
          home: Scaffold(
            body: MockQuestionDetailsDialog(
              question: _listeningQuestion(status: 'published'),
              displayPosition: 7,
              linkedMock: Future<MockAdminTest?>.value(null),
              qaHistory: Stream.value(const []),
              onEdit: () {},
              onAdvanceQa: null,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Q7'), findsOneWidget);
      expect(find.text('Question preview & QA details'), findsOneWidget);
      expect(find.text('Section 1'), findsWidgets);
      expect(find.text('Play audio'), findsOneWidget);
      expect(find.text('A. Westminster'), findsOneWidget);
      expect(find.text('B. Buckingham Palace'), findsOneWidget);
      expect(find.text('Westminster'), findsOneWidget);
      expect(find.text('Published'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing a published question clearly warns that save resets QA to draft',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.darkTheme,
          home: Scaffold(
            body: MockQuestionEditorDialog(
              question: _listeningQuestion(status: 'published'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Saving changes will first return this question'),
        findsOneWidget,
      );
      expect(find.text('Save as draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

MockAdminQuestion _listeningQuestion({required String status}) {
  return MockAdminQuestion(
    id: 'q-1',
    track: MockAdminTrack.academic,
    skill: MockAdminSkill.listening,
    number: 1,
    sectionId: 'section_1',
    type: 'multiple_choice',
    prompt: 'Where will the group meet before the tour begins?',
    passage: '',
    transcript: 'The guide asks everyone to meet at Westminster.',
    audioUrl: 'https://example.test/listening.mp3',
    audioStoragePath: 'mock_audio/job-1/section-1.mp3',
    audioDurationSeconds: 95,
    options: const ['Westminster', 'Buckingham Palace', 'Tower Bridge'],
    correctAnswers: const ['Westminster'],
    marks: 1,
    explanation:
        'The guide explicitly identifies Westminster as the meeting point.',
    wordLimit: 'Choose ONE answer.',
    instructions: 'Listen and select the correct option.',
    difficulty: 'Intermediate',
    status: status,
    mockTestId: 'mock-1',
    sourceType: 'ai_generated',
    sourceReference: 'generation/job-1',
    copyrightStatus: 'ai_generated_reviewed',
    validationStatus: 'passed',
    qualityScore: 94,
    isPublished: status == 'published',
    generationJobId: 'job-1',
    generatedBy: 'gemini',
    generatedModel: 'test-model',
    metadata: const {'topic': 'London travel', 'part': 1},
  );
}
