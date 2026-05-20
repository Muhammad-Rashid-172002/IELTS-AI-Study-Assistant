import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/routes_names.dart';

class BottomNavigation extends StatefulWidget {
  final int index;

  const BottomNavigation({
    super.key,
    required this.index,
  });

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  late int myIndex;

  final List<IconData> iconList = [
    Icons.home_rounded,
    Icons.bar_chart_rounded,
    Icons.person_rounded,
  ];

  final List<String> labels = [
    "Home",
    "Progress",
    "Profile",
  ];

  @override
  void initState() {
    super.initState();
    myIndex = widget.index;
  }

  void onTap(int index) {
    if (index == myIndex) return;

    setState(() => myIndex = index);

    switch (index) {
      case 0:
        Get.offAllNamed(RoutesName.home);
        break;

      case 1:
        Get.offAllNamed(RoutesName.progress);
        break;

      case 2:
        Get.offAllNamed(RoutesName.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
          ),
          child: Container(
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                iconList.length,
                (index) {
                  final isSelected = index == myIndex;

                  return GestureDetector(
                    onTap: () => onTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF2DD4BF),
                                  Color(0xFF14B8A6),
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF14B8A6)
                                      .withOpacity(0.45),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            iconList[index],
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.55),
                            size: 24,
                          ),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: isSelected
                                ? Row(
                                    children: [
                                      const SizedBox(width: 10),
                                      Text(
                                        labels[index],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}