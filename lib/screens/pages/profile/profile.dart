import 'dart:ui';
import 'package:flutter/material.dart';
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

  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final phoneC = TextEditingController();

  bool isEditing = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    services.loadUserProfile().then((_) => _fillFields());
  }

  void _fillFields() {
    final data = services.userData;
    nameC.text = data['name'] ?? '';
    emailC.text = data['email'] ?? '';
    phoneC.text = data['phone'] ?? '';
    setState(() {});
  }

  Future<void> _saveChanges() async {
    setState(() => isSaving = true);

    await services.updateFirestoreProfile(
      name: nameC.text.trim(),
      phone: phoneC.text.trim(),
    );

    Get.snackbar(
      "Success",
      "Profile updated",
      backgroundColor: Colors.black87,
      colorText: Colors.white,
    );

    setState(() {
      isSaving = false;
      isEditing = false;
    });
  }

  Future<void> _logout() async {
    await services.signOut();
    Get.offAllNamed(RoutesName.login);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = services.userData;

      return Scaffold(
        backgroundColor: const Color(0xfff5f5f7),
        bottomNavigationBar: BottomNavigation(index: 2),

        body: CustomScrollView(
          slivers: [
            /// 🔥 APP STORE STYLE HEADER
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    /// Background Gradient
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xff1d1d1f), Color(0xff2c2c2e)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),

                    /// Blur Effect
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(color: Colors.black.withOpacity(0.2)),
                    ),

                    /// Profile Info
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage(
                            (data['profileImage'] != null &&
                                    data['profileImage'].toString().isNotEmpty)
                                ? data['profileImage']
                                : "https://cdn-icons-png.flaticon.com/512/149/149071.png",
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          nameC.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          emailC.text,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            /// 🔽 CONTENT
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    /// ✨ GLASS CARD
                    _glassCard(
                      child: Column(
                        children: [
                          _buildField(nameC, "Full Name", isEditing),
                          const SizedBox(height: 12),
                          _buildField(emailC, "Email", false),
                          const SizedBox(height: 12),
                          _buildField(phoneC, "Phone", isEditing),
                          const SizedBox(height: 20),

                          isEditing
                              ? _primaryButton("Save Changes", _saveChanges)
                              : _outlineButton(
                                  "Edit Profile",
                                  () => setState(() => isEditing = true),
                                ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// ⚡ ACTIONS
                    _glassCard(
                      child: Column(
                        children: [
                          _tile(Icons.help_outline, "Help & Support", () {
                            launchUrl(
                              Uri.parse(
                                "https://ielts-support-portal.vercel.app/",
                              ),
                            );
                          }),
                          _tile(Icons.lock_outline, "Privacy Policy", () {
                            launchUrl(
                              Uri.parse(
                                "hhttps://ielts-privacy-police.vercel.app/",
                              ),
                            );
                          }),
                          _tile(Icons.info_outline, "About App", () {
                            launchUrl(
                              Uri.parse("https://ieltsabout.vercel.app/"),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// 🚪 LOGOUT
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.red,
                        ),
                        child: const Center(
                          child: Text(
                            "Logout",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// ✨ GLASS CARD
  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }

  /// 🔹 FIELD
  Widget _buildField(controller, label, enabled) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// 🔵 PRIMARY BUTTON
  Widget _primaryButton(String text, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: isSaving ? null : onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: Colors.black,
      ),
      child: isSaving
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(text),
    );
  }

  /// ⚪ OUTLINE BUTTON
  Widget _outlineButton(String text, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(text),
    );
  }

  /// 🔹 TILE
  Widget _tile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}
