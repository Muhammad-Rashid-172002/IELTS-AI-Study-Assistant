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

  // Icons
  final List<IconData> iconList = [
    Icons.home,
    Icons.book_outlined,
    Icons.analytics_outlined,
    Icons.people,
  ];

  // Labels
  final List<String> labels = [
    "Home",
    "Vocabulary",
    "Progress",
    "Profile",
  ];

  // Colors
  static const Color blue = Color(0xFF1E88E5);
  static const Color grey = Colors.grey;

  @override
  void initState() {
    super.initState();
    myIndex = widget.index; // ✅ Correct initialization
  }

  void onTap(int index) {
    if (index == myIndex) return;

    setState(() {
      myIndex = index;
    });

    switch (index) {
      case 0:
        Get.offAllNamed(RoutesName.home);
        break;
      case 1:
        Get.offAllNamed(RoutesName.vocabularybuilder);
        break;
      case 2:
        Get.offAllNamed(RoutesName.progress);
        break;
      case 3:
        Get.offAllNamed(RoutesName.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey, width: 0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(iconList.length, (index) {
          final bool isSelected = index == myIndex;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    iconList[index],
                    size: 26,
                    color: isSelected ? blue : grey,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? blue : grey,
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