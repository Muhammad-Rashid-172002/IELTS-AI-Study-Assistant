

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:image_picker/image_picker.dart';
import '../../../controller/firebase_services/firebase_services.dart';
import '../../../controller/summarizer_controller/summarizer_controller.dart';

class Summarizer extends StatefulWidget {
  const Summarizer({super.key});

  @override
  State<Summarizer> createState() => _SummarizerState();
}

class _SummarizerState extends State<Summarizer> {
  String _length = "Medium";
  bool _bulletPoints = true;
  final TextEditingController _textController = TextEditingController();
  int _charCount = 0;
  // final SummarizerController controller = Get.put(SummarizerController());
  //final controller = Get.put(SummarizerController());
  final controller = Get.find<SummarizerController>();

  @override
  void initState() {
    super.initState();

    final fs = Get.find<FirebaseServices>();
    fs.loadUserProfile();   // ⭐ FIX — real-time sync works now

    _textController.addListener(() {
      setState(() {
        _charCount = _textController.text.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),

     // -------------------------------------------------------
     // APP BAR
     // -------------------------------------------------------
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: 72,
        automaticallyImplyLeading: false,

        title: Row(
          children: [
            // BACK BUTTON
            _roundButton(Icons.arrow_back, onTap: () => Navigator.pop(context)),

            const SizedBox(width: 14),

            // HEADER ICON
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF4A79F6).withOpacity(0.15),
              ),
              child: const Icon(Icons.description,
                  color: Color(0xFF4A79F6), size: 22),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Text Summarizer",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "AI-Powered Analysis",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // MENU BUTTON
            // _roundButton(Icons.more_vert),
            PopupMenuButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.more_vert, color: Colors.black87, size: 22),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 18),
                      SizedBox(width: 10),
                      Text("Copy Summary"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 2,
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18),
                      SizedBox(width: 10),
                      Text("Clear All"),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 1) {
                  if (controller.result.value.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: controller.result.value));
                    Get.snackbar("Copied", "Summary copied to clipboard",
                        backgroundColor: Colors.green, colorText: Colors.white);
                  }
                } else if (value == 2) {
                  _textController.clear();
                  controller.result.value = "";
                  setState(() => _charCount = 0);
                }
              },
            ),

          ],
        ),
      ),

     // -------------------------------------------------------
      //BODY
     // -------------------------------------------------------

      body: WillPopScope(
        onWillPop: () async => true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
        
              // ---------------------------------------------------
              // HOW IT WORKS BANNER
              // ---------------------------------------------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDDEBFF), Color(0xFFE9F3FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  // 🔥 LEFT BORDER EXACT LIKE SCREENSHOT
                  border: Border(
                    left: BorderSide(
                      color: Colors.blue,
                      width: 4,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        size: 22, color: Color(0xFF4A79F6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Paste or type your text below. Our AI will analyze and generate a concise summary highlighting key points.",
                        style: TextStyle(
                          color: Colors.black87,
                          height: 1.4,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        
              const SizedBox(height: 22),
        
              // ---------------------------------------------------
              // INPUT TEXT CARD
              // ---------------------------------------------------
              _inputCard(),
        
              const SizedBox(height: 22),
        
              // ---------------------------------------------------
              // SUMMARY OPTIONS CARD
              // ---------------------------------------------------
              _optionsCard(),
        
              const SizedBox(height: 26),
        
              // ---------------------------------------------------
              // SUMMARIZE BUTTON
              // ---------------------------------------------------
              _summarizeButton(),
              // HERE 👇🏼 PLACE THE RESULT BOX
              const SizedBox(height: 26),
              Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4A79F6)),
                  );
                }
        
                if (controller.result.value.isEmpty) {
                  return const SizedBox();
                }
        
                return _resultCard(controller.result.value);
              }),
            ],
          ),
        ),
      ),
    );
  }
  Widget _inputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ---------------- TITLE + CLEAR ----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Input Text",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              GestureDetector(
                onTap: () {
                  _textController.clear();
                  setState(() => _charCount = 0);
                },
                child: const Text(
                  "Clear",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A79F6),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ---------------- INPUT FIELD ----------------
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                counterText: "",
                hintText: "Paste or type your text here...",
                hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ---------------- BUTTONS ----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _secondaryButton(Icons.content_paste, "Paste", onTap: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  setState(() {
                    _textController.text = data!.text!;
                    _charCount = data.text!.length;
                  });
                }
              }),

              const SizedBox(width: 12),

              _secondaryButton(Icons.auto_fix_high, "Sample", onTap: () {
                const sample = """
Artificial Intelligence (AI) helps machines learn, process language, recognize patterns and make decisions. 
It includes deep learning, NLP, robotics, reasoning, and more.
""";
                setState(() {
                  _textController.text = sample;
                  _charCount = sample.length;
                });
              }),

              const SizedBox(width: 12),

              _secondaryButton(Icons.image, "Image", onTap: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery);

                if (picked != null) {
                  final file = File(picked.path);
                  controller.summarizeImage(file);
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _optionsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Summary Options",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // LENGTH ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.tune, size: 20, color: Colors.black54),
                  SizedBox(width: 10),
                  Text(
                    "Summary Length",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF1F4FA),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _length,
                    items: ["Short", "Medium", "Long"]
                        .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => _length = v!),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.black12),

          // BULLET POINTS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.list, size: 20, color: Colors.black54),
                  SizedBox(width: 10),
                  Text(
                    "Bullet Points",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              Switch(
                value: _bulletPoints,
                activeColor: const Color(0xFF4A79F6),
                onChanged: (v) => setState(() => _bulletPoints = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ------------------------------------------------------------
  // SUMMARIZE BUTTON
  // ------------------------------------------------------------
  Widget _summarizeButton() {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4A79F6),
            Color(0xFF8FB2FF),
          ],
        ),
      ),
      child: TextButton.icon(
        onPressed: () async {
          print("BUTTON CLICKED");
          if (_textController.text.trim().isEmpty) {
            Get.snackbar("Error", "Please enter text",
                backgroundColor: Colors.red, colorText: Colors.white);
            return;
          }
          print("CLICKED");
          // Call controller — it handles progress update internally
          await controller.summarize(
            _textController.text.trim(),
            _length,
            _bulletPoints,
          );
          print("SUMMARY COMPLETED");
        },

        icon: const Icon(Icons.bolt, color: Colors.white),
        label: const Text(
          "Summarize Text",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }



  Widget _secondaryButton(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFF4F6FA),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ROUND BUTTON (Back / Menu)
  // ------------------------------------------------------------
  Widget _roundButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }
  // ------------------------------------------------------------
  // COMMON CARD DECORATION
  // ------------------------------------------------------------
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }


  Widget _resultCard(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------
          // HEADER BAR
          // ------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4A79F6),
                  Color(0xFF6DA3FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Summary Result",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                Row(
                  children: [
                    // COPY BUTTON
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: text));
                        Get.snackbar(
                          "Copied",
                          "Summary copied to clipboard",
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 1),
                        );
                      },
                      child: const Icon(Icons.copy, color: Colors.white, size: 20),
                    ),
                    // const SizedBox(width: 16),
                    //
                    // // SHARE BUTTON
                    // GestureDetector(
                    //   onTap: () {
                    //     Share.share(text);
                    //   },
                    //   child: const Icon(Icons.share, color: Colors.white, size: 20),
                    // ),
                  ],
                )
              ],
            ),
          ),

          // ------------------------------------
          // CONTENT AREA
          // ------------------------------------
          Container(
            padding: const EdgeInsets.all(18),
            constraints: const BoxConstraints(
              minHeight: 120,
              maxHeight: 320, // scroll will activate when content is long
            ),
            child: SingleChildScrollView(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


}