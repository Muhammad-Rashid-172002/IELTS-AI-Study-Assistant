// import 'package:flutter/material.dart';
// import '../../../../resources/colors/colors.dart';
//
// class RoundButton2 extends StatelessWidget {
//   final double width;
//   final double height;
//   final bool loading;
//   final String? title;
//   final VoidCallback onPress;
//   final Color? borderColor;
//   final Color? textColor;
//   final Widget? child;
//
//   const RoundButton2({
//     super.key,
//     required this.width,
//     required this.height,
//     required this.loading,
//     this.title,
//     required this.onPress,
//     this.borderColor,
//     this.textColor,
//     this.child,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final isDark = theme.brightness == Brightness.dark;
//
//     return InkWell(
//       borderRadius: BorderRadius.circular(15),
//       onTap: loading ? null : onPress,
//       child: Container(
//         width: width,
//         height: height,
//         decoration: BoxDecoration(
//           color: Colors.transparent,
//           borderRadius: BorderRadius.circular(15),
//           border: Border.all(
//             color: borderColor ??
//                 (isDark ? AppColor.gold : AppColor.emeraldGreen),
//             width: 2,
//           ),
//         ),
//         child: loading
//             ? const Center(child: CircularProgressIndicator())
//             : Center(
//           child: child ??
//               Text(
//                 title ?? '',
//                 style: theme.textTheme.titleLarge?.copyWith(
//                   color: textColor ??
//                       (isDark
//                           ? AppColor.gold
//                           : AppColor.emeraldGreen),
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';

class RoundButton2 extends StatelessWidget {
  final double width;
  final double height;
  final bool loading;
  final String? title;
  final VoidCallback onPress;
  final Color? borderColor;
  final Color? textColor;
  final Widget? child;

  const RoundButton2({
    super.key,
    required this.width,
    required this.height,
    required this.loading,
    this.title,
    required this.onPress,
    this.borderColor,
    this.textColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: loading ? null : onPress,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor ?? Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : child ??
              Text(
                title ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? Colors.black87,
                ),
              ),
        ),
      ),
    );
  }
}
