


import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

    await services.loadUserProfile();

    Get.snackbar(
      "Profile Updated",
      "Your changes have been successfully saved.",
      backgroundColor: Colors.green,
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
    final theme = Theme.of(context);

    return Obx(() {
      final data = services.userData;

      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            isEditing ? "Edit Profile" : "Profile",
            style: theme.textTheme.headlineSmall,
          ),
          centerTitle: true,
        ),

        bottomNavigationBar: const BottomNavigation(index: 4),

        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              /// -------------------------
              /// PROFILE CARD (IELTS STYLE)
              /// -------------------------
              Card(
                elevation: 2,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundImage: (data['profileImage'] != null &&
                            data['profileImage'].toString().isNotEmpty)
                            ? NetworkImage(data['profileImage'])
                            : const NetworkImage(
                          "https://cdn-icons-png.flaticon.com/512/149/149071.png",
                        ),
                      ),

                      const SizedBox(height: 20),

                      _buildField(
                        controller: nameC,
                        label: "Full Name",
                        enabled: isEditing,
                      ),

                      const SizedBox(height: 16),

                      _buildField(
                        controller: emailC,
                        label: "Email",
                        enabled: false,
                      ),

                      const SizedBox(height: 16),

                      _buildField(
                        controller: phoneC,
                        label: "Phone Number",
                        enabled: isEditing,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 22),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isEditing
                            ? FilledButton(
                          key: const ValueKey("saveBtn"),
                          onPressed: isSaving ? null : _saveChanges,
                          child: isSaving
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text("Save Changes"),
                        )
                            : OutlinedButton(
                          key: const ValueKey("editBtn"),
                          onPressed: () =>
                              setState(() => isEditing = true),
                          child: const Text("Edit Profile"),
                        ),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// -------------------------
              /// LOGOUT
              /// -------------------------
              ListTile(
                onTap: _logout,
                leading: Icon(Icons.logout,
                    color: theme.colorScheme.error, size: 28),
                title: Text(
                  "Logout",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            ],
          ),
        ),
      );
    });
  }

  /// ---------------------------------------------
  /// SINGLE INPUT FIELD (Auto matches AppTheme)
  /// ---------------------------------------------
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }
}
