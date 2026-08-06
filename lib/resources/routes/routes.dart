import 'package:fyproject/resources/routes/routes_names.dart';
import 'package:fyproject/screens/Onboarding_Screen/Onboarding_screen.dart';
import 'package:fyproject/screens/pages/home/home.dart';
import 'package:fyproject/screens/pages/profile/presentation/profile_screen.dart';

import 'package:fyproject/screens/pages/progress/presentation/progress_dashboard_screen.dart';
import 'package:fyproject/screens/pages/registration/registration.dart';
import 'package:get/get_navigation/src/routes/get_route.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import '../splash_screen/spalsh_screen.dart';

class AppRoutes {
  static List<GetPage<dynamic>> appRoutes() => [
    GetPage(
      name: RoutesName.splash,
      page: () => const SplashScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: RoutesName.onboarding,
      page: () => const PremiumOnboardingScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: RoutesName.home,
      page: () => const HomeDashboard(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    // GetPage(
    //   name: RoutesName.login,
    //   page: () => const Login(),
    //   transition: Transition.leftToRightWithFade,
    //   transitionDuration: const Duration(milliseconds: 250),
    // ),
    GetPage(
      name: RoutesName.register,
      page: () => const RegistrationScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 250),
    ),

    // GetPage(
    //   name: RoutesName.vocabularybuilder,
    //   page: () => Vocabularybuilder(),
    //   transition: Transition.leftToRightWithFade,
    //   transitionDuration: const Duration(milliseconds: 250),
    // ),
    GetPage(
      name: RoutesName.profile,
      page: () => const ProfileScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: RoutesName.progress,
      page: () => const ProgressDashboardScreen(),
      transition: Transition.leftToRightWithFade,
      transitionDuration: const Duration(milliseconds: 250),
    ),
  ];
}
