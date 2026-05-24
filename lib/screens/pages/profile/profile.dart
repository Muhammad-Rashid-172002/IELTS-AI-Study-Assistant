import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fyproject/screens/help_and%20_Support/help_and_support.dart';
import 'package:fyproject/services/image_picker.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../controller/firebase_services/firebase_services.dart';
import '../../../../resources/bottom_navigation_bar/botton_navigation.dart';
import '../../../../resources/routes/routes_names.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final FirebaseServices services = Get.find<FirebaseServices>();

  final TextEditingController nameC = TextEditingController();
  final TextEditingController emailC = TextEditingController();
  final TextEditingController phoneC = TextEditingController();

  bool isEditing = false;
  bool isSaving = false;
  String? selectedImagePath;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await services.loadUserProfile();
      _fillFields();
      setState(() {});
    });
  }

  void _fillFields() {
    final data = services.userData;

    nameC.text = data['name']?.toString() ?? '';
    emailC.text = data['email']?.toString() ?? '';
    phoneC.text = data['phone']?.toString() ?? '';
  }

  Future<void> _saveChanges() async {
    try {
      setState(() {
        isSaving = true;
      });

      await services.updateFirestoreProfile(
        name: nameC.text.trim(),
        phone: phoneC.text.trim(),
      );

      setState(() {
        isSaving = false;
        isEditing = false;
      });

      showCustomSnackBar(
        context: context,
        title: "Success",
        message: "Profile updated successfully",
      );
    } catch (e) {
      setState(() {
        isSaving = false;
      });

      showCustomSnackBar(
        context: context,
        title: "Error",
        message: "Something went wrong",
        isError: true,
      );
    }
  }

  Future<void> _logout() async {
    await services.signOut();
    Get.offAllNamed(RoutesName.login);
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      showCustomSnackBar(
        context: context,
        title: "Error",
        message: "Could not launch URL",
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    nameC.dispose();
    emailC.dispose();
    phoneC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = services.userData;

      final profileImage =
          (data['profileImage'] != null &&
              data['profileImage'].toString().isNotEmpty)
          ? data['profileImage'].toString()
          : "https://cdn-icons-png.flaticon.com/512/149/149071.png";

      return Scaffold(
        backgroundColor: const Color(0xFF08111F),
        bottomNavigationBar: const BottomNavigation(index: 2),

        body: CustomScrollView(
          slivers: [
            /// HEADER
            SliverAppBar(
              expandedHeight: 340,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xFF08111F),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(34),
                  bottomRight: Radius.circular(34),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF08111F),
                        Color(0xFF102A43),
                        Color(0xFF0F766E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withOpacity(0.20),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2DD4BF),
                                    Color(0xFF14B8A6),
                                    Color(0xFF0F766E),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF14B8A6,
                                    ).withOpacity(0.35),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 58,
                                backgroundColor: const Color(0xFF111827),
                                backgroundImage: selectedImagePath != null
                                    ? FileImage(File(selectedImagePath!))
                                    : NetworkImage(profileImage)
                                          as ImageProvider,
                              ),
                            ),

                            GestureDetector(
                              onTap: () async {
                                File? image =
                                    await ImagePickerHelper.showImagePicker(
                                      context,
                                    );

                                if (image != null) {
                                  try {
                                    setState(() {
                                      selectedImagePath = image.path;
                                      isSaving = true;
                                    });

                                    await services.updateProfileImage(image);
                                    await services.loadUserProfile();

                                    setState(() {
                                      selectedImagePath = null;
                                      isSaving = false;
                                    });

                                    showCustomSnackBar(
                                      context: context,
                                      title: "Success",
                                      message:
                                          "Profile image updated successfully",
                                      isError: false,
                                    );
                                  } catch (e) {
                                    setState(() => isSaving = false);

                                    showCustomSnackBar(
                                      context: context,
                                      title: "Error",
                                      message:
                                          "Image upload failed. Please try again.",
                                      isError: true,
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2DD4BF),
                                      Color(0xFF14B8A6),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 19,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        Text(
                          data['name']?.toString().isEmpty ?? true
                              ? "User Name"
                              : data['name'].toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          data['email']?.toString().isEmpty ?? true
                              ? "example@gmail.com"
                              : data['email'].toString(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.70),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 18),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: const Text(
                            "IELTS Student",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            /// STATS
            // SliverToBoxAdapter(
            //   child: Padding(
            //     padding: const EdgeInsets.all(16),

            //     child: Row(
            //       children: [
            //         Expanded(child: _statsCard("12", "Tests")),

            //         const SizedBox(width: 12),

            //         Expanded(child: _statsCard("7.5", "Band")),

            //         const SizedBox(width: 12),

            //         Expanded(child: _statsCard("28", "Days")),
            //       ],
            //     ),
            //   ),
            // ),

            /// MAIN CONTENT
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),

                child: Column(
                  children: [
                    SizedBox(height: 10),

                    /// PROFILE CARD
                    _glassCard(
                      child: Column(
                        children: [
                          _buildField(
                            controller: nameC,
                            label: "Full Name",
                            icon: Icons.person_outline_rounded,
                            enabled: isEditing,
                          ),

                          const SizedBox(height: 16),

                          _buildField(
                            controller: emailC,
                            label: "Email",
                            icon: Icons.email_outlined,
                            enabled: false,
                          ),

                          const SizedBox(height: 16),

                          _buildField(
                            controller: phoneC,
                            label: "Phone Number",
                            icon: Icons.phone_outlined,
                            enabled: isEditing,
                          ),

                          const SizedBox(height: 24),

                          isEditing
                              ? _primaryButton("Save Changes", _saveChanges)
                              : _outlineButton("Edit Profile", () {
                                  setState(() {
                                    isEditing = true;
                                  });
                                }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// ACTIONS CARD
                    _glassCard(
                      child: Column(
                        children: [
                          _tile(
                            Icons.help_outline_rounded,
                            "Help & Support",
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HelpSupportScreen(),
                                ),
                              );
                            },
                          ),

                          _tile(
                            Icons.lock_outline_rounded,
                            "Privacy Policy",
                            () {
                              _openUrl("https://ielts-ai-privacy.vercel.app/");
                            },
                          ),

                          const SizedBox(height: 18),

                          Text(
                            "Version 1.0.0",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 18),

                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Column(
                              children: const [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF2DD4BF),
                                      size: 18,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "AI Band Score Prediction",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 12),

                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF2DD4BF),
                                      size: 18,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Real IELTS Mock Tests",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 12),

                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF2DD4BF),
                                      size: 18,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Speaking & Writing Evaluation",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          Text(
                            "Developed by M.Rashid",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    /// LOGOUT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 64,

                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFEF4444),
                              Color(0xFFDC2626),
                              Color(0xFFB91C1C),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),

                          borderRadius: BorderRadius.circular(24),

                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withOpacity(0.35),
                              blurRadius: 26,
                              offset: const Offset(0, 14),
                            ),

                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),

                        child: Material(
                          color: Colors.transparent,

                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),

                            onTap: () {
                              showDialog(
                                context: context,
                                barrierDismissible: true,

                                builder: (context) {
                                  return Dialog(
                                    backgroundColor: Colors.transparent,
                                    insetPadding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),

                                    child: Container(
                                      padding: const EdgeInsets.all(28),

                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.12),
                                            Colors.white.withOpacity(0.05),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),

                                        borderRadius: BorderRadius.circular(34),

                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.10),
                                        ),

                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.30,
                                            ),
                                            blurRadius: 28,
                                            offset: const Offset(0, 14),
                                          ),
                                        ],
                                      ),

                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          /// ICON
                                          Container(
                                            padding: const EdgeInsets.all(20),

                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFEF4444),
                                                  Color(0xFFDC2626),
                                                ],
                                              ),

                                              shape: BoxShape.circle,

                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFFEF4444,
                                                  ).withOpacity(0.35),

                                                  blurRadius: 24,
                                                  offset: const Offset(0, 10),
                                                ),
                                              ],
                                            ),

                                            child: const Icon(
                                              Icons.logout_rounded,
                                              color: Colors.white,
                                              size: 40,
                                            ),
                                          ),

                                          const SizedBox(height: 24),

                                          /// TITLE
                                          const Text(
                                            "Logout Account?",
                                            textAlign: TextAlign.center,

                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 25,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.3,
                                            ),
                                          ),

                                          const SizedBox(height: 12),

                                          /// SUBTITLE
                                          Text(
                                            "Are you sure you want to logout from your account? You can login again anytime.",
                                            textAlign: TextAlign.center,

                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.68,
                                              ),
                                              fontSize: 15,
                                              height: 1.6,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),

                                          const SizedBox(height: 30),

                                          /// BUTTONS
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  height: 56,

                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.08),

                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),

                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.10),
                                                    ),
                                                  ),

                                                  child: Material(
                                                    color: Colors.transparent,

                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            18,
                                                          ),

                                                      onTap: () {
                                                        Navigator.pop(context);
                                                      },

                                                      child: const Center(
                                                        child: Text(
                                                          "Cancel",

                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(width: 14),

                                              Expanded(
                                                child: Container(
                                                  height: 56,

                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                          colors: [
                                                            Color(0xFFEF4444),
                                                            Color(0xFFDC2626),
                                                          ],
                                                        ),

                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),

                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(
                                                          0xFFEF4444,
                                                        ).withOpacity(0.30),

                                                        blurRadius: 18,
                                                        offset: const Offset(
                                                          0,
                                                          8,
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  child: Material(
                                                    color: Colors.transparent,

                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            18,
                                                          ),

                                                      onTap: () async {
                                                        Navigator.pop(context);

                                                        _logout();
                                                      },

                                                      child: const Center(
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .logout_rounded,
                                                              color:
                                                                  Colors.white,
                                                              size: 20,
                                                            ),

                                                            SizedBox(width: 8),

                                                            Text(
                                                              "Logout",

                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },

                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.logout_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),

                                  SizedBox(width: 10),

                                  Text(
                                    "Logout",

                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16.5,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // /// STATS CARD
  // Widget _statsCard(String value, String title) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(vertical: 20),

  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(22),

  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.05),
  //           blurRadius: 12,
  //           offset: const Offset(0, 6),
  //         ),
  //       ],
  //     ),

  //     child: Column(
  //       children: [
  //         Text(
  //           value,
  //           style: const TextStyle(
  //             fontSize: 24,
  //             fontWeight: FontWeight.bold,
  //             color: Color(0xff0f172a),
  //           ),
  //         ),

  //         const SizedBox(height: 6),

  //         Text(
  //           title,
  //           style: const TextStyle(
  //             color: Colors.grey,
  //             fontWeight: FontWeight.w500,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  /// GLASS CARD
  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(34),

        border: Border.all(
          color: const Color(0xFF2DD4BF).withOpacity(0.12),
          width: 1.2,
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD4BF).withOpacity(0.10),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, 14),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),

      child: child,
    );
  }

  /// TEXT FIELD
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),

      margin: const EdgeInsets.only(bottom: 20),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(30),

        border: Border.all(
          color: enabled
              ? const Color(0xFF2DD4BF).withOpacity(0.18)
              : Colors.white.withOpacity(0.05),
          width: 1.2,
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD4BF).withOpacity(0.12),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 12),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: TextField(
        controller: controller,
        enabled: enabled,

        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15.5,
          letterSpacing: 0.2,
        ),

        cursorColor: const Color(0xFF2DD4BF),

        decoration: InputDecoration(
          labelText: label,

          hintText: "Enter your $label",

          floatingLabelBehavior: FloatingLabelBehavior.always,

          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.32),
            fontWeight: FontWeight.w500,
          ),

          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.68),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),

          prefixIcon: Container(
            margin: const EdgeInsets.all(10),

            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2DD4BF),
                  Color(0xFF14B8A6),
                  Color(0xFF0F766E),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),

              borderRadius: BorderRadius.circular(18),

              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2DD4BF).withOpacity(0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),

            child: Icon(icon, color: Colors.white, size: 21),
          ),

          suffixIcon: !enabled
              ? Icon(
                  Icons.lock_rounded,
                  color: Colors.white.withOpacity(0.35),
                  size: 20,
                )
              : Icon(
                  Icons.edit_rounded,
                  color: const Color(0xFF2DD4BF).withOpacity(0.70),
                  size: 20,
                ),

          filled: true,
          fillColor: Colors.transparent,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 24,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
          ),

          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.03)),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color(0xFF2DD4BF), width: 1.7),
          ),
        ),
      ),
    );
  }

  /// PRIMARY BUTTON
  /// PREMIUM PRIMARY BUTTON
  Widget _primaryButton(String text, VoidCallback onTap) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),

      height: 62,
      width: double.infinity,

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(26),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: isSaving ? null : onTap,

          child: Center(
            child: isSaving
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.6,
                        ),
                      ),

                      SizedBox(width: 14),

                      Text(
                        "Saving...",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),

                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons.save_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// PREMIUM OUTLINE BUTTON
  Widget _outlineButton(String text, VoidCallback onTap) {
    return Container(
      height: 62,
      width: double.infinity,

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
        ),

        borderRadius: BorderRadius.circular(26),

        border: Border.all(
          color: const Color(0xFF2DD4BF).withOpacity(0.25),
          width: 1.3,
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD4BF).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),

          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,

          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4BF).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),

                  child: const Icon(
                    Icons.edit_rounded,
                    color: Color(0xFF2DD4BF),
                    size: 20,
                  ),
                ),

                const SizedBox(width: 12),

                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// TILE
  Widget _tile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.white.withOpacity(0.55),
        ),
      ),
    );
  }

  void showCustomSnackBar({
    required BuildContext context,
    required String title,
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(18),

        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isError
                  ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                  : [
                      const Color(0xFF0F172A),
                      const Color(0xFF111827),
                      const Color(0xFF0F766E),
                    ],

              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),

            borderRadius: BorderRadius.circular(22),

            border: Border.all(
              color: isError
                  ? Colors.redAccent.withOpacity(0.25)
                  : const Color(0xFF2DD4BF).withOpacity(0.18),
            ),

            boxShadow: [
              BoxShadow(
                color: isError
                    ? Colors.red.withOpacity(0.25)
                    : const Color(0xFF14B8A6).withOpacity(0.22),

                blurRadius: 24,
                offset: const Offset(0, 12),
              ),

              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),

          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),

                child: Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_rounded,

                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Text(
                      title,

                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      message,

                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// TextFields me premium prefix icon box add karo.
// Save/Edit buttons ko animated gradient style do.
// Logout dialog ko dark premium dialog banao, abhi white hai.
// Get.snackbar ki jagah custom dark snackbar use karo.
// Stats card uncomment karo: Tests, Avg Band, Practice Days.
// const BottomNavigation(index: 2) se const hata do agar dynamic rebuild issue aaye.
