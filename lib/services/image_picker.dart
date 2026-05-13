import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerHelper {

  static final ImagePicker _picker = ImagePicker();

  /// CAMERA
  static Future<File?> pickFromCamera() async {

    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (image != null) {
      return File(image.path);
    }

    return null;
  }

  /// GALLERY
  static Future<File?> pickFromGallery() async {

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      return File(image.path);
    }

    return null;
  }

  /// BOTTOM SHEET
  static Future<File?> showImagePicker(
    BuildContext context,
  ) async {

    File? selectedImage;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                const Text(
                  "Select Image",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 25),

                Row(
                  children: [

                    /// CAMERA
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {

                          selectedImage =
                              await pickFromCamera();

                          Navigator.pop(context);
                        },

                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: const Column(
                            children: [

                              Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.greenAccent,
                                size: 40,
                              ),

                              SizedBox(height: 10),

                              Text(
                                "Camera",
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 15),

                    /// GALLERY
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {

                          selectedImage =
                              await pickFromGallery();

                          Navigator.pop(context);
                        },

                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: const Column(
                            children: [

                              Icon(
                                Icons.photo_library_rounded,
                                color: Colors.blueAccent,
                                size: 40,
                              ),

                              SizedBox(height: 10),

                              Text(
                                "Gallery",
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );

    return selectedImage;
  }
}