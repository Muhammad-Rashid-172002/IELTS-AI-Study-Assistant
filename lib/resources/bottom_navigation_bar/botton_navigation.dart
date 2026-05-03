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

  final List<IconData> iconList = [
    Icons.home_outlined,
    Icons.bar_chart_outlined,
    Icons.person_outline,
  ];

  final List<IconData> activeIconList = [
    Icons.home,
    Icons.bar_chart,
    Icons.person,
  ];

  final List<String> labels = ["Home", "Progress", "Profile"];

  static const Color activeColor = Color(0xFF007AFF); // iOS blue
  static const Color inactiveColor = Colors.grey;

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
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.6),
        ),
      ),
      child: Row(
        children: List.generate(iconList.length, (index) {
          final isSelected = index == myIndex;

          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected ? activeIconList[index] : iconList[index],
                      key: ValueKey(isSelected),
                      size: 26,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
