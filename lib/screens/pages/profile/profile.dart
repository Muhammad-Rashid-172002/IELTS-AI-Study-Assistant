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
            style: theme.textTheme.titleLarge,
          ),
          centerTitle: true,
        ),

        bottomNavigationBar: BottomNavigation(index: 2),

        body: SingleChildScrollView(
          child: Column(
            children: [
              /// 🔥 HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xff4facfe), Color(0xff00f2fe)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundImage: NetworkImage(
                        (data['profileImage'] != null &&
                                data['profileImage'].toString().isNotEmpty)
                            ? data['profileImage']
                            : "https://cdn-icons-png.flaticon.com/512/149/149071.png",
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      nameC.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      emailC.text,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    /// 🧾 PROFILE INFO CARD
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            _buildField(
                              controller: nameC,
                              label: "Full Name",
                              enabled: isEditing,
                            ),
                            const SizedBox(height: 12),
                            _buildField(
                              controller: emailC,
                              label: "Email",
                              enabled: false,
                            ),
                            const SizedBox(height: 12),
                            _buildField(
                              controller: phoneC,
                              label: "Phone",
                              enabled: isEditing,
                            ),

                            const SizedBox(height: 20),

                            isEditing
                                ? ElevatedButton.icon(
                                    onPressed: isSaving ? null : _saveChanges,
                                    icon: const Icon(Icons.save),
                                    label: isSaving
                                        ? const CircularProgressIndicator(
                                            color: Colors.white,
                                          )
                                        : const Text("Save Changes"),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: () =>
                                        setState(() => isEditing = true),
                                    icon: const Icon(Icons.edit),
                                    label: const Text("Edit Profile"),
                                  ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// ⚡ QUICK ACTIONS
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          _tile(Icons.help_outline, "Help & Support", () {}),
                          _tile(Icons.privacy_tip, "Privacy Policy", () {}),
                          _tile(Icons.info_outline, "About App", () {}),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// 🚪 LOGOUT
                    Card(
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ListTile(
                        onTap: _logout,
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          "Logout",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// 🔹 INPUT FIELD
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// 🔹 LIST TILE
  Widget _tile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}
