import 'package:flutter/material.dart';
import 'package:fyproject/Controller/onboarding_controller.dart';
import 'package:fyproject/utils/app_colors.dart';


class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final OnboardingController controller = OnboardingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: controller.pageController,
              itemCount: controller.pages.length,
              onPageChanged: (index) {
                setState(() {
                  controller.currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final page = controller.pages[index];
                return Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(page.image, height: 250),
                      SizedBox(height: 40),
                      Text(
                        page.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      Text(
                        page.description,
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              controller.pages.length,
              (index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 5),
                width: controller.currentPage == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: controller.currentPage == index
                      ? AppColors.primaryColor
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: () {
            //   Navigator.push(context, route)
              },
              child: Text(
                  controller.currentPage == controller.pages.length - 1
                      ? "Get Started"
                      : "Next"),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: AppColors.primaryColor,
              ),
            ),
          )
        ],
      ),
    );
  }
}
