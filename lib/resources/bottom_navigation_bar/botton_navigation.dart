import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/routes_names.dart';

class BottomNavigation extends StatefulWidget {
  final int index;
  const BottomNavigation({super.key, required this.index});

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  late int myIndex;

  @override
  void initState() {
    super.initState();
    myIndex = widget.index;
  }

  final iconList = const [
    Icons.home_rounded,
    Icons.bar_chart_rounded,
    Icons.bookmark_rounded,
    Icons.person_rounded,
  ];

  final labels = const [
    "Home",
    "Progress",
    "Saved",
    "Profile",
  ];

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
        Get.offAllNamed(RoutesName.saved);
        break;
      case 3:
        Get.offAllNamed(RoutesName.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final inactive = Colors.grey.shade500;

    return SafeArea(
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(iconList.length, (index) {
            final isSelected = index == myIndex;

            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        iconList[index],
                        size: 26,
                        color: isSelected ? primary : inactive,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? primary : inactive,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
