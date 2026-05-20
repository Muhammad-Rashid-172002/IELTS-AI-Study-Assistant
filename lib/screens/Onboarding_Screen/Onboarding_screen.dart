import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/registration/registration.dart';

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
      "title": "Master IELTS Skills",
      "desc": "Practice Listening, Reading, Writing and Speaking with smart AI guidance.",
      "image": "assets/images/on1.png",
    },
    {
      "title": "Track Your Band Score",
      "desc": "Monitor your progress, identify weak areas, and improve step by step.",
      "image": "assets/images/on2.png",
    },
    {
      "title": "Achieve Band 7+",
      "desc": "Experience real IELTS-style practice tests and boost your confidence.",
      "image": "assets/images/on3.png",
    },
  ];

  void nextPage() {
    if (currentIndex < onboardingData.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Registration()),
      );
    }
  }

  void skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Registration()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF08111F),
              Color(0xFF102A43),
              Color(0xFF0F766E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Text(
                        "${currentIndex + 1}/${onboardingData.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: skip,
                      child: const Text(
                        "Skip",
                        style: TextStyle(
                          color: Color(0xFF99F6E4),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: onboardingData.length,
                  onPageChanged: (index) {
                    setState(() => currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final item = onboardingData[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 330,
                            width: double.infinity,
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(34),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF14B8A6).withOpacity(0.25),
                                  blurRadius: 35,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 450),
                              scale: currentIndex == index ? 1.0 : 0.92,
                              child: Image.asset(
                                item["image"]!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          const SizedBox(height: 38),

                          Text(
                            item["title"]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 31,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.6,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            item["desc"]!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.72),
                            ),
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
                  onboardingData.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: currentIndex == index ? 30 : 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: currentIndex == index
                          ? const Color(0xFF2DD4BF)
                          : Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                child: GestureDetector(
                  onTap: nextPage,
                  child: Container(
                    height: 62,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2DD4BF),
                          Color(0xFF14B8A6),
                          Color(0xFF0F766E),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF14B8A6).withOpacity(0.45),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentIndex == onboardingData.length - 1
                              ? "Start IELTS Practice"
                              : "Continue",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}