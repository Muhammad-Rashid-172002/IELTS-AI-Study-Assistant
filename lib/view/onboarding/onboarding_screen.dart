import 'package:flutter/material.dart';
import 'package:fyproject/Controller/onboarding_controller.dart';
import 'package:fyproject/utils/app_colors.dart';
import 'package:fyproject/view/auth/SigninScreen.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with SingleTickerProviderStateMixin {
  final OnboardingController controller = OnboardingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryDark,
              AppColors.primaryMid,
              AppColors.primaryLight,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: controller.pageController,
                  itemCount: controller.pages.length,
                  onPageChanged: (index) {
                    setState(() => controller.currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final page = controller.pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Soft zoom effect on images
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutBack,
                            child: Image.asset(
                              page.image,
                              height: 260,
                            ),
                          ),

                          const SizedBox(height: 50),

                          // Title
                          Text(
                            page.title,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.3,
                              letterSpacing: 0.8,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 18),

                          // Description
                          Text(
                            page.description,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.85),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Modern Smooth Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  controller.pages.length,
                  (index) {
                    bool active = controller.currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: active ? 26 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 35),

              // Start / Next Button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.currentPage ==
                        controller.pages.length - 1) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SigninScreen()),
                      );
                    } else {
                      controller.pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: Colors.white.withOpacity(0.35),
                  ),
                  child: Text(
                    controller.currentPage == controller.pages.length - 1
                        ? "Get Started"
                        : "Next",
                    style: const TextStyle(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
