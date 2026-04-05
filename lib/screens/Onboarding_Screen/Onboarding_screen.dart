import 'package:flutter/material.dart';

import 'package:fyproject/screens/pages/registration/registration.dart';
import 'package:fyproject/screens/widgets/botton/round_botton.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Learn Anytime 📚",
      "desc": "Practice IELTS anytime with smart lessons and guidance.",
      "image": "assets/images/on1.png",
    },
    {
      "title": "Track Your Progress 📊",
      "desc": "Monitor your band score and improve step by step.",
      "image": "assets/images/on2.png",
    },
    {
      "title": "Achieve Band 7+ 🎯",
      "desc": "Get ready with mock tests and real exam experience.",
      "image": "assets/images/on3.png",
    },
  ];

  void nextPage() {
    if (currentIndex < onboardingData.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.ease,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Registration()),
      );
    }
  }

  void skip() {
    _controller.jumpToPage(onboardingData.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            /// Skip Button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: skip,
                child: const Text(
                  "Skip",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),

            /// PageView
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: onboardingData.length,
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        /// Image
                        Image.asset(
                          onboardingData[index]["image"]!,
                          height: 250,
                        ),

                        const SizedBox(height: 40),

                        /// Title
                        Text(
                          onboardingData[index]["title"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// Description
                        Text(
                          onboardingData[index]["desc"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            /// Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                onboardingData.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentIndex == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentIndex == index
                        ? Colors.white
                        : Colors.white38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// Next Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: RoundButton(
                title: currentIndex == onboardingData.length - 1
                    ? "Get Started"
                    : "Next",
                onPress: nextPage,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
