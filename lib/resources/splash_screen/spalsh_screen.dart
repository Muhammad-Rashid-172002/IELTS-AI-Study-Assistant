
// import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/resources/splash_services/splash_services.dart';



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
    splashService.startSplash(context);
  }

  @override
  Widget build(BuildContext context) {
    return   Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
      
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/ai.png',
                  height: MediaQuery.of(context).size.height * 0.35, //  35% of screen height
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