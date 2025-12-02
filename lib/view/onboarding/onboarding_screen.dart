import 'package:flutter/material.dart';
import 'package:fyproject/Controller/onboarding_controller.dart';
import 'package:fyproject/utils/app_colors.dart';
import 'package:fyproject/view/auth/login_view.dart';

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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryColor,
              AppColors.primaryColor.withOpacity(0.7),
              Colors.black87,
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
                          // Image with soft fade animation effect
                          AnimatedContainer(
                            duration: Duration(milliseconds: 600),
                            curve: Curves.easeOutBack,
                            child: Image.asset(
                              page.image,
                              height: 260,
                            ),
                          ),

                          SizedBox(height: 50),

                          // Title
                          Text(
                            page.title,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 20),

                          Text(
                            page.description,
                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.white70,
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
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: 5),
                      width: active ? 26 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: 30),

              // Premium Button
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 25, vertical: 10),
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.currentPage ==
                        controller.pages.length - 1) {
                      // TODO: Navigate to next screen
                      Navigator.push(context, MaterialPageRoute(builder: (context) => SigninScreen()));
                    } else {
                      controller.pageController.nextPage(
                        duration: Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                  ),
                  child: Text(
                    controller.currentPage == controller.pages.length - 1
                        ? "Get Started"
                        : "Next",
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
