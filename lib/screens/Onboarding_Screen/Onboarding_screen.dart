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
      "title": "Learn Anytime",
      "desc":
          "Practice IELTS anytime with smart lessons and AI guidance.",
      "image": "assets/images/on1.png",
    },
    {
      "title": "Track Progress",
      "desc":
          "Monitor your band score and improve step by step.",
      "image": "assets/images/on2.png",
    },
    {
      "title": "Achieve Band 7+",
      "desc":
          "Mock tests + real exam experience to boost your score.",
      "image": "assets/images/on3.png",
    },
  ];

  void nextPage() {
    if (currentIndex < onboardingData.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Registration()),
      );
    }
  }

  void skip() {
    _controller.animateToPage(
      onboardingData.length - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        /// 🌈 BACKGROUND
       

        child: SafeArea(
          child: Column(
            children: [
              /// 🔘 TOP BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${currentIndex + 1}/${onboardingData.length}",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: skip,
                      child: const Text(
                        "Skip",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),

              /// 📄 PAGES
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: onboardingData.length,
                  onPageChanged: (index) {
                    setState(() => currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          /// 🖼 IMAGE
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: currentIndex == index ? 280 : 240,
                            child: Image.asset(
                              onboardingData[index]["image"]!,
                            ),
                          ),

                          const SizedBox(height: 40),

                          /// 📝 TITLE
                          Text(
                            onboardingData[index]["title"]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),

                          const SizedBox(height: 16),

                          /// 📄 DESC
                          Text(
                            onboardingData[index]["desc"]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              /// 🔘 INDICATOR (MODERN)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  onboardingData.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: currentIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentIndex == index
                          ? Colors.black
                          : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// 🚀 NEXT BUTTON
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: RoundButton(
                  title: currentIndex == onboardingData.length - 1
                      ? "Get Started"
                      : "Next",
                  onPress: nextPage,
                ),
              ),
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 24),
              //   child: GestureDetector(
              //     onTap: nextPage,
              //     child: Container(
              //       height: 60,
              //       width: double.infinity,
              //       decoration: BoxDecoration(
              //         color: Colors.white,
              //         borderRadius: BorderRadius.circular(18),
              //       ),
              //       child: Center(
              //         child: Text(
              //           currentIndex == onboardingData.length - 1
              //               ? "Get Started"
              //               : "Next",
              //           style: const TextStyle(
              //             color: Color(0xff4a00e0),
              //             fontSize: 16,
              //             fontWeight: FontWeight.bold,
              //           ),
              //         ),
              //       ),
              //     ),
              //   ),
              // ),

              // const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}