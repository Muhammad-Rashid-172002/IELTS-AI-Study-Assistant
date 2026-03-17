//
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../routes/routes_names.dart';
//
// class Splashscreen extends StatefulWidget {
//   const Splashscreen({super.key});
//
//   @override
//   State<Splashscreen> createState() => _SplashscreenState();
// }
//
// class _SplashscreenState extends State<Splashscreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _fadeAnimation;
//   late Animation<double> _scaleAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     );
//
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
//         .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
//
//     _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0)
//         .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
//
//     _controller.forward();
//
//     Timer(const Duration(seconds: 3), () {
//       Get.offAllNamed(RoutesName.home);
//     });
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: FadeTransition(
//         opacity: _fadeAnimation,
//         child: ScaleTransition(
//           scale: _scaleAnimation,
//           child: Center(
//             child: Image.asset(
//               'assets/images/ai.png',
//               width: MediaQuery.of(context).size.width * 0.6,
//               fit: BoxFit.cover,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../splash_services/splash_services.dart';


class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

SplashService  splashService = SplashService();

class _SplashscreenState extends State<Splashscreen> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    splashService.isLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return   Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        // children: [
        //   Center(
        //     child: Text(
        //       'My Project',
        //       style: TextStyle(
        //         fontWeight: FontWeight.bold,
        //         fontSize: 30,
        //         color: Theme.of(context).colorScheme.onSurface, // ✅ Auto adapts to light/dark
        //         letterSpacing: 0.5, // subtle readability
        //       ),
        //     ),
        //   ),
        // ],
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/ai.png',
                  height: MediaQuery.of(context).size.height * 0.35, // 🔸 35% of screen height
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}