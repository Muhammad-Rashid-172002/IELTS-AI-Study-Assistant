enum StartupDestination {
  onboarding,
  verifyEmail,
  blocked,
  profileSetup,
  diagnostic,
  studyPlan,
  main,
  offlineUnavailable,
}

class StartupAccessPolicy {
  const StartupAccessPolicy._();

  static StartupDestination decide({
    required bool signedIn,
    required bool emailVerified,
    required Map<String, dynamic> profile,
    required bool offline,
  }) {
    if (!signedIn) return StartupDestination.onboarding;
    if (!emailVerified) return StartupDestination.verifyEmail;

    final status = (profile['accountStatus'] ?? 'active')
        .toString()
        .toLowerCase();
    if (profile['isDisabled'] == true ||
        status == 'disabled' ||
        status == 'blocked' ||
        status == 'suspended') {
      return StartupDestination.blocked;
    }

    final profileCompleted = profile['profileCompleted'] == true;
    final diagnosticCompleted = profile['diagnosticCompleted'] == true;
    final studyPlanRequired = profile['studyPlanRequired'] == true;
    final activeStudyPlan = profile['activeStudyPlan'] == true;

    if (offline) {
      return profileCompleted &&
              diagnosticCompleted &&
              (!studyPlanRequired || activeStudyPlan)
          ? StartupDestination.main
          : StartupDestination.offlineUnavailable;
    }
    if (!profileCompleted) return StartupDestination.profileSetup;
    if (!diagnosticCompleted) return StartupDestination.diagnostic;
    if (studyPlanRequired && !activeStudyPlan) {
      return StartupDestination.studyPlan;
    }
    return StartupDestination.main;
  }
}
