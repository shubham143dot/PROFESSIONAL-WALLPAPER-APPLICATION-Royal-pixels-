import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/utils/imagekit_upload.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../domain/usecases/add_wallpaper_usecase.dart';
import '../../providers/wallpaper_provider.dart';
import '../../../core/utils/safe_tap.dart';

class UploadWallpaperPage extends ConsumerStatefulWidget {
  const UploadWallpaperPage({super.key});

  @override
  ConsumerState<UploadWallpaperPage> createState() => _UploadWallpaperPageState();
}

class _UploadWallpaperPageState extends ConsumerState<UploadWallpaperPage> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _diamondCostController = TextEditingController(text: '100');

  File? _selectedImage;
  bool _isPremium = false;
  bool _isUltraHD = false;
  bool _isEditorsChoice = false;
  bool _isUploading = false;
  
  List<String> _existingCategories = [];
  String? _selectedCategory;
  bool _createNewCategory = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickImage() async {
    SafeTap.run('admin_pick_image', () async {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    });
  }

  Future<void> _upload() async {
    SafeTap.run('admin_upload_submit', () async {
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
        // 1. Upload image (ImageKit first → Cloudinary fallback for free; Cloudinary premium for premium)
        final imageUrl = await ImageKitUpload.uploadImage(
          _selectedImage!,
          isPremiumOrSpecial: _isPremium,
        );
        
        if (imageUrl == null) {
          throw Exception('Failed to upload image. Please check your connection and try again.');
        }

        // 2. Build category
        String finalCategory = 'Feed';
        if (_createNewCategory) {
          finalCategory = _categoryController.text.trim().isEmpty ? 'Feed' : _categoryController.text.trim();
        } else if (_selectedCategory != null && _selectedCategory != 'Create New Category') {
          finalCategory = _selectedCategory!;
        }
        if (finalCategory.isNotEmpty) {
          finalCategory = finalCategory[0].toUpperCase() + finalCategory.substring(1);
        }

        // 3. Build tags
        final tags = [finalCategory.toLowerCase()];
        if (_isUltraHD) tags.add('ultra_hd');
        if (_isEditorsChoice) tags.add('editors_choice');

        // 4. Save to Firestore
        final wallpaper = WallpaperEntity(
          id: '',
          title: _titleController.text.trim(),
          imageUrl: imageUrl,
          category: finalCategory,
          isPremium: _isPremium,
          diamondCost: _isPremium ? (int.tryParse(_diamondCostController.text.trim()) ?? 100) : 0,
          tags: tags,
        );

        final addUseCase = sl<AddWallpaperUseCase>();
        final result = await addUseCase(wallpaper);

        result.fold(
          (failure) => throw Exception(failure.message),
          (_) {
            // Success! 
            // Reload wallpapers so it reflects in the app instantly
            ref.read(wallpaperProvider.notifier).loadWallpapers();
            
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Wallpaper Uploaded Successfully! 🚀')),
            );
            context.pop(); // Go back home
          },
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _diamondCostController.dispose();
    super.dispose();
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
    if (!dropDownItems.contains('Create New Category')) {
      dropDownItems.add('Create New Category');
    }

    if (_selectedCategory == null && dropDownItems.isNotEmpty) {
      _selectedCategory = dropDownItems.first;
      _createNewCategory = _selectedCategory == 'Create New Category';
    } else if (_selectedCategory != null && !dropDownItems.contains(_selectedCategory)) {
      _selectedCategory = dropDownItems.first;
      _createNewCategory = _selectedCategory == 'Create New Category';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Admin Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                Text('Tap to choose wallpaper', style: TextStyle(color: Colors.white54)),
                              ],
                            )
                          : const SizedBox(),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Title Field
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Wallpaper Title',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: dropDownItems.contains(_selectedCategory) ? _selectedCategory : dropDownItems.first,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: dropDownItems.map((c) {
                      return DropdownMenuItem(
                        value: c, 
                        child: Text(c, style: TextStyle(color: c == 'Create New Category' ? Colors.amber : Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val;
                        _createNewCategory = val == 'Create New Category';
                      });
                    },
                  ),
                  
                  // Conditional New Category Field
                  if (_createNewCategory) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _categoryController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'New Category Name',
                        labelStyle: const TextStyle(color: Colors.amber),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.amber)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.amber)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.amber, width: 2)),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),

                  // ── Section: Content Type ────────────────────────────
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Content Type',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  
                  // Premium Toggle
                  _AdminToggle(
                    icon: Icons.workspace_premium,
                    iconColor: Colors.amber,
                    label: 'Mark as Premium',
                    subtitle: 'Requires PRO subscription or custom 💎 to unlock',
                    value: _isPremium,
                    onChanged: (val) => setState(() => _isPremium = val),
                  ),
                  
                  // Diamond cost input — only shown when Premium is ON
                  if (_isPremium) ...[  
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.withAlpha(70)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('💎', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Diamond Cost', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                const Text('Diamonds required to unlock this wallpaper', style: TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: _diamondCostController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 18),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                filled: true,
                                fillColor: Colors.amber.withAlpha(20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.amber)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.amber, width: 0.8)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.amber, width: 2)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 12),

                  // ── Section: Tags ────────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 10),
                    child: Text(
                      'Tags',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                  // Ultra HD Toggle
                  _AdminToggle(
                    icon: Icons.hd_rounded,
                    iconColor: const Color(0xFF22D3EE),
                    label: 'Ultra HD / 4K',
                    subtitle: 'Shows a cyan "4K" badge on the wallpaper card',
                    value: _isUltraHD,
                    activeColor: const Color(0xFF22D3EE),
                    onChanged: (val) => setState(() => _isUltraHD = val),
                  ),

                  const SizedBox(height: 12),

                  // Editor's Choice Toggle
                  _AdminToggle(
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFFBBF24),
                    label: "Editor's Choice",
                    subtitle: 'Shows an amber "★ PICK" badge on the wallpaper card',
                    value: _isEditorsChoice,
                    activeColor: const Color(0xFFFBBF24),
                    onChanged: (val) => setState(() => _isEditorsChoice = val),
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
                    child: const Text('Publish Wallpaper', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Reusable admin toggle row ────────────────────────────────────────────────

class _AdminToggle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _AdminToggle({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value
            ? activeColor.withAlpha(20)
            : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? activeColor.withAlpha(80) : Colors.white12,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
