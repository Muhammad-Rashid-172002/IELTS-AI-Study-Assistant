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

  final List<Map<String, dynamic>> onboardingData = [
    {
      "title": "Listen Better",
      "desc":
          "Improve your listening skills with real IELTS tests and instant AI feedback.",
      "image": "assets/images/listenig.png",
      "color": Color(0xFF38BDF8),
    },
    {
      "title": "Read Smarter",
      "desc":
          "Practice IELTS reading passages and learn how to answer faster and accurately.",
      "image": "assets/images/reading.png",
      "color": Color(0xFFA855F7),
    },
    {
      "title": "Write with Confidence",
      "desc":
          "Improve Task 1 and Task 2 writing with AI band score evaluation.",
      "image": "assets/images/writing.png",
      "color": Color(0xFFF97316),
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
    final Color accent = onboardingData[currentIndex]["color"];

    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF050B18),
              const Color(0xFF08111F),
              accent.withOpacity(0.22),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _topBadge("${currentIndex + 1}/${onboardingData.length}"),
                    TextButton(
                      onPressed: skip,
                      child: Text(
                        "Skip",
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
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
                  onPageChanged: (index) =>
                      setState(() => currentIndex = index),
                  itemBuilder: (context, index) {
                    final item = onboardingData[index];
                    final Color pageColor = item["color"];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 350,
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.055),
                              borderRadius: BorderRadius.circular(38),
                              border: Border.all(
                                color: pageColor.withOpacity(0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: pageColor.withOpacity(0.22),
                                  blurRadius: 38,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.asset(
                                item["image"],
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          const SizedBox(height: 38),

                          ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: [Colors.white, pageColor],
                              ).createShader(bounds);
                            },
                            child: Text(
                              item["title"],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 36,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            item["desc"],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.68),
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
                children: List.generate(onboardingData.length, (index) {
                  final bool selected = currentIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: selected ? 34 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: selected ? accent : Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                child: GestureDetector(
                  onTap: nextPage,
                  child: Container(
                    height: 64,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withOpacity(0.95),
                          accent.withOpacity(0.65),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.35),
                          blurRadius: 26,
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
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 12),
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

  Widget _topBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
