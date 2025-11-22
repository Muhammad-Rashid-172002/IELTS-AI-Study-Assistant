import 'package:flutter/material.dart';
import 'package:fyproject/model/onboarding_model.dart';


class OnboardingController {
  PageController pageController = PageController();
  int currentPage = 0;

  List<OnboardingModel> pages = [
    OnboardingModel(
      image: "assets/images/step1.png",
      title: "Welcome to IELTS AI Assistant",
      description: "Prepare for IELTS smartly with AI-powered tools.",
    ),
    OnboardingModel(
      image: "assets/images/step2.png",
      title: "Practice Reading & Writing",
      description: "Generate summaries and MCQs instantly.",
    ),
    OnboardingModel(
      image: "assets/images/step3.png",
      title: "Speaking & Listening",
      description: "Interactive AI feedback for speaking and listening.",
    ),
  ];

  void nextPage(BuildContext context, int totalPages) {
    if (currentPage < totalPages - 1) {
      currentPage++;
      pageController.animateToPage(
        currentPage,
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to Login Screen
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}
