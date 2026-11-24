import 'package:flutter_test/flutter_test.dart';
import 'package:fyproject/services/startup_access_policy.dart';

void main() {
  StartupDestination decide({
    bool signedIn = true,
    bool verified = true,
    bool offline = false,
    bool requireVerification = true,
    Map<String, dynamic> profile = const {
      'accountStatus': 'active',
      'profileCompleted': true,
      'diagnosticCompleted': true,
    },
  }) {
    return StartupAccessPolicy.decide(
      signedIn: signedIn,
      emailVerified: verified,
      profile: profile,
      offline: offline,
      requireEmailVerification: requireVerification,
    );
  }

  test('routes signed-out and unverified users safely', () {
    expect(decide(signedIn: false), StartupDestination.onboarding);
    expect(decide(verified: false), StartupDestination.verifyEmail);
  });

  test('unverified users pass when email verification is disabled', () {
    expect(
      decide(verified: false, requireVerification: false),
      StartupDestination.main,
    );
    expect(
      decide(verified: false, requireVerification: false, profile: const {}),
      StartupDestination.profileSetup,
    );
    expect(
      decide(signedIn: false, requireVerification: false),
      StartupDestination.onboarding,
    );
    expect(
      decide(
        verified: false,
        requireVerification: false,
        profile: const {
          'accountStatus': 'suspended',
          'profileCompleted': true,
          'diagnosticCompleted': true,
        },
      ),
      StartupDestination.blocked,
    );
  });

  test('blocks suspended learners before main navigation', () {
    expect(
      decide(
        profile: const {
          'accountStatus': 'suspended',
          'profileCompleted': true,
          'diagnosticCompleted': true,
        },
      ),
      StartupDestination.blocked,
    );
  });

  test('enforces profile, diagnostic, and required plan order', () {
    expect(decide(profile: const {}), StartupDestination.profileSetup);
    expect(
      decide(
        profile: const {'accountStatus': 'active', 'profileCompleted': true},
      ),
      StartupDestination.diagnostic,
    );
    expect(
      decide(
        profile: const {
          'accountStatus': 'active',
          'profileCompleted': true,
          'diagnosticCompleted': true,
          'studyPlanRequired': true,
          'activeStudyPlan': false,
        },
      ),
      StartupDestination.studyPlan,
    );
  });

  test('offline entry is limited to fully completed cached state', () {
    expect(decide(offline: true), StartupDestination.main);
    expect(
      decide(
        offline: true,
        profile: const {
          'accountStatus': 'active',
          'profileCompleted': true,
          'diagnosticCompleted': false,
        },
      ),
      StartupDestination.offlineUnavailable,
    );
  });
}
