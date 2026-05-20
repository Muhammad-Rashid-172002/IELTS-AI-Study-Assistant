import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fyproject/services/image_picker.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../controller/firebase_services/firebase_services.dart';
import '../../../../resources/bottom_navigation_bar/botton_navigation.dart';
import '../../../../resources/routes/routes_names.dart';
import 'dart:ui' as ui;

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

      Get.snackbar(
        "Success",
        "Profile updated successfully",
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      setState(() {
        isSaving = false;
      });

      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
      Get.snackbar(
        "Error",
        "Could not launch URL",
        backgroundColor: const Color(0xffef4444),
        colorText: Colors.white,
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
              expandedHeight: 320,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xff2563EB),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF08111F),
                        Color(0xFF102A43),
                        Color(0xFF0F766E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),

                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        /// PROFILE IMAGE
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 2,
                                ),
                              ),

                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: Colors.white,

                                /// IMAGE SHOW
                                backgroundImage: selectedImagePath != null
                                    ? FileImage(File(selectedImagePath!))
                                    : NetworkImage(profileImage)
                                          as ImageProvider,
                              ),
                            ),

                            /// CAMERA BUTTON
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

                                    Get.snackbar(
                                      "Success",
                                      "Profile image updated successfully",
                                      backgroundColor: Colors.green,
                                      colorText: Colors.white,
                                    );
                                  } catch (e) {
                                    setState(() => isSaving = false);

                                    Get.snackbar(
                                      "Error",
                                      "Image upload failed. Please try again.",
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                    );
                                  }
                                }
                              },

                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xff2563EB),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),

                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        /// NAME
                        Text(
                          nameC.text.isEmpty ? "User Name" : nameC.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        /// EMAIL
                        Text(
                          emailC.text.isEmpty
                              ? "example@gmail.com"
                              : emailC.text,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// BADGE
                        // Container(
                        //   padding: const EdgeInsets.symmetric(
                        //     horizontal: 18,
                        //     vertical: 8,
                        //   ),

                        //   decoration: BoxDecoration(
                        //     color: Colors.white.withOpacity(0.12),
                        //     borderRadius: BorderRadius.circular(30),
                        //   ),

                        //   child: const Text(
                        //     "Premium Student",
                        //     style: TextStyle(
                        //       color: Colors.white,
                        //       fontWeight: FontWeight.w600,
                        //     ),
                        //   ),
                        // ),
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
                              _openUrl(
                                "https://ielts-support-portal.vercel.app/",
                              );
                            },
                          ),

                          _tile(
                            Icons.lock_outline_rounded,
                            "Privacy Policy",
                            () {
                              _openUrl(
                                "https://ielts-privacy-police.vercel.app/",
                              );
                            },
                          ),

                          _tile(Icons.info_outline_rounded, "About App", () {
                            _openUrl("https://ieltsabout.vercel.app/");
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    /// LOGOUT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            builder: (context) {
                              return Dialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      /// ICON
                                      Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xffef4444,
                                          ).withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.logout_rounded,
                                          color: Color(0xffef4444),
                                          size: 38,
                                        ),
                                      ),

                                      const SizedBox(height: 20),

                                      /// TITLE
                                      const Text(
                                        "Logout Account?",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      /// SUBTITLE
                                      const Text(
                                        "Are you sure you want to logout from your account?",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 15,
                                          height: 1.5,
                                        ),
                                      ),

                                      const SizedBox(height: 28),

                                      /// BUTTONS
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                              style: OutlinedButton.styleFrom(
                                                minimumSize:
                                                    const ui.Size.fromHeight(
                                                      52,
                                                    ),
                                                side: BorderSide(
                                                  color: Colors.grey.shade300,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: const Text(
                                                "Cancel",
                                                style: TextStyle(
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 14),

                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                Navigator.pop(context);

                                                /// LOGOUT FUNCTION
                                                _logout();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xffef4444,
                                                ),
                                                minimumSize:
                                                    const ui.Size.fromHeight(
                                                      52,
                                                    ),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: const Text(
                                                "Logout",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
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

                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                        ),

                        label: const Text(
                          "Logout",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffef4444),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      cursorColor: const Color(0xFF2DD4BF),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
        prefixIcon: Icon(icon, color: const Color(0xFF2DD4BF)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF2DD4BF), width: 1.4),
        ),
      ),
    );
  }

  /// PRIMARY BUTTON
  Widget _primaryButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: isSaving ? null : onTap,
      child: Container(
        height: 58,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6), Color(0xFF0F766E)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14B8A6).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  /// OUTLINE BUTTON
  Widget _outlineButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2DD4BF)),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF2DD4BF),
              fontWeight: FontWeight.w900,
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
}
