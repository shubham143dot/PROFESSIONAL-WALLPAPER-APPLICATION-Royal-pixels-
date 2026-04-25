import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/imagekit_upload.dart';
import '../../providers/wallpaper_provider.dart';
import '../../../core/utils/safe_tap.dart';

class UploadCategoryCoverPage extends ConsumerStatefulWidget {
  const UploadCategoryCoverPage({super.key});

  @override
  ConsumerState<UploadCategoryCoverPage> createState() => _UploadCategoryCoverPageState();
}

class _UploadCategoryCoverPageState extends ConsumerState<UploadCategoryCoverPage> {
  File? _selectedImage;
  bool _isUploading = false;
  
  List<String> _existingCategories = [];
  String? _selectedCategory;

  Future<void> _pickImage() async {
    SafeTap.run('admin_pick_cover', () async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSizeInBytes = await file.length();
        final fileSizeInMb = fileSizeInBytes / (1024 * 1024);
        
        if (fileSizeInMb > 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cover size must be under 2 MB. Selected file is ${fileSizeInMb.toStringAsFixed(2)} MB.'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedImage = file;
        });
      }
    });
  }

  Future<void> _upload() async {
    SafeTap.run('admin_upload_cover', () async {
      if (_selectedImage == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select an image first!')),
          );
        }
        return;
      }
      
      setState(() => _isUploading = true);

      try {
        // 1. Upload image (ImageKit with Cloudinary fallback for free covers)
        final imageUrl = await ImageKitUpload.uploadImage(_selectedImage!);
        
        if (imageUrl == null) {
          throw Exception('Failed to upload image. Please check your connection and try again.');
        }

        // 2. Save directly to Firestore collection 'category_covers'
        // Use lowercase category name as doc id
        final categoryKey = _selectedCategory!.toLowerCase();
        await FirebaseFirestore.instance.collection('category_covers').doc(categoryKey).set({
          'coverUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Overrode $_selectedCategory cover successfully! 🚀')),
        );
        context.pop(); // Go back
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically derive categories
    final wallpaperState = ref.watch(wallpaperProvider);
    final allWallpapers = [
      ...wallpaperState.freeWallpapers,
      ...wallpaperState.premiumWallpapers,
    ];
    final Map<String, String> catMap = {};
    for (var wp in allWallpapers) {
      String cat = wp.category.trim();
      if (cat.isEmpty) cat = wp.autoCategory.trim();
      if (cat.isEmpty) continue;
      
      final lowerKey = cat.toLowerCase();
      if (!catMap.containsKey(lowerKey)) {
        catMap[lowerKey] = cat;
      } else {
        // Prefer capitalized versions over lowercase ones
        final existing = catMap[lowerKey]!;
        if (existing.isNotEmpty && existing[0].toLowerCase() == existing[0] && cat.isNotEmpty && cat[0].toUpperCase() == cat[0]) {
          catMap[lowerKey] = cat;
        }
      }
    }
    _existingCategories = catMap.values.toList()..sort();
    
    List<String> dropDownItems = [..._existingCategories];

    if (_selectedCategory == null && dropDownItems.isNotEmpty) {
      _selectedCategory = dropDownItems.first;
    } else if (_selectedCategory != null && !dropDownItems.contains(_selectedCategory)) {
      if (dropDownItems.isNotEmpty) {
        _selectedCategory = dropDownItems.first;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Manage Category Cover', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.amber),
                  SizedBox(height: 16),
                  Text('Uploading to ImageKit & Firebase...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image Preview / Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImage == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 50, color: Colors.amber),
                                SizedBox(height: 12),
                                Text('Tap to choose cover image', style: TextStyle(color: Colors.white54)),
                              ],
                            )
                          : const SizedBox(),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: dropDownItems.contains(_selectedCategory) ? _selectedCategory : null,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Select Category',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: dropDownItems.map((c) {
                      return DropdownMenuItem(
                        value: c, 
                        child: Text(c, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Upload Button
                  ElevatedButton(
                    onPressed: _upload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Set Category Cover', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
