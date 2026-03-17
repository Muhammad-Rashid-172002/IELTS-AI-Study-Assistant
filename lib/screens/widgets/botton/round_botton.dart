// import 'package:flutter/material.dart';
//
// class RoundButton extends StatelessWidget {
//   final bool loading;
//   final String title;
//   final VoidCallback onPress;
//   final double height, width;
//   final Color? buttonColor;
//   final Color? textColor;
//
//   const RoundButton({
//     super.key,
//     this.loading = false,
//     required this.title,
//     required this.onPress,
//     this.width = double.infinity,
//     this.height = 55,
//     this.buttonColor,
//     this.textColor,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final isDark = theme.brightness == Brightness.dark;
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(15),
//         onTap: loading ? null : onPress,
//         child: Container(
//           height: height,
//           width: width,
//           decoration: BoxDecoration(
//             color:
//                 buttonColor ??
//                 (isDark ? AppColor.gold.withOpacity(0.9) : AppColor.gold),
//             borderRadius: BorderRadius.circular(15),
//             boxShadow: [
//               BoxShadow(
//                 color: AppColor.gold.withOpacity(0.3),
//                 blurRadius: 8,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: loading
//               ? const Center(
//                   child: CircularProgressIndicator(color: Colors.white),
//                 )
//               : Center(
//                   child: Text(
//                     title,
//                     style: theme.textTheme.titleLarge?.copyWith(
//                       color:
//                           textColor ??
//                           (isDark ? Colors.black : AppColor.whiteColor),
//                       fontWeight: FontWeight.bold,
//                       letterSpacing: 0.8,
//                     ),
//                   ),
//                 ),
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';

class RoundButton extends StatelessWidget {
  final bool loading;
  final String title;
  final VoidCallback onPress;
  final double height, width;

  const RoundButton({
    super.key,
    this.loading = false,
    required this.title,
    required this.onPress,
    this.width = double.infinity,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: loading ? null : onPress,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF4A79F6), // Main blue
              Color(0xFF8FB2FF), // Light blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
