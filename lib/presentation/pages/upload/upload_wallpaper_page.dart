import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/utils/cloudinary_upload.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../../domain/usecases/add_wallpaper_usecase.dart';
import '../../providers/wallpaper_provider.dart';

class UploadWallpaperPage extends ConsumerStatefulWidget {
  const UploadWallpaperPage({super.key});

  @override
  ConsumerState<UploadWallpaperPage> createState() => _UploadWallpaperPageState();
}

class _UploadWallpaperPageState extends ConsumerState<UploadWallpaperPage> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController(text: '10.0');

  File? _selectedImage;
  bool _isPremium = false;
  bool _isSpecial = false;
  bool _isUploading = false;
  
  List<String> _existingCategories = [];
  String? _selectedCategory;
  bool _createNewCategory = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Do not compress image to prevent quality drop
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }



  Future<void> _upload() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first.')),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a title.')),
      );
      return;
    }

    // Check for duplicate wallpaper name
    final wallpaperState = ref.read(wallpaperProvider);
    final allWallpapers = [
      ...wallpaperState.freeWallpapers,
      ...wallpaperState.premiumWallpapers,
    ];
    
    final isDuplicate = allWallpapers.any((wp) => wp.title.toLowerCase() == title.toLowerCase());
    
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A wallpaper with this name is already taken!')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload to Cloudinary
      final imageUrl = await CloudinaryUpload.uploadImage(
        _selectedImage!,
        isPremiumOrSpecial: _isPremium || _isSpecial,
      );
      
      if (imageUrl == null) {
        throw Exception('Failed to upload image to Cloudinary');
      }

      // 2. Save to Firestore
      final double price = _isSpecial ? (double.tryParse(_priceController.text) ?? 10.0) : 0.0;
      
      String finalCategory = 'Trending';
      if (_createNewCategory) {
        finalCategory = _categoryController.text.trim().isEmpty ? 'Trending' : _categoryController.text.trim();
      } else if (_selectedCategory != null && _selectedCategory != 'Create New Category') {
        finalCategory = _selectedCategory!;
      }

      final tags = [finalCategory.toLowerCase()];
      if (_isSpecial) {
        tags.add('special');
      }

      final wallpaper = WallpaperEntity(
        id: '', // Empty ID tells our datasource to auto-generate one
        title: title,
        imageUrl: imageUrl,
        category: finalCategory,
        isPremium: _isPremium,
        price: price,
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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically derive categories so that if wallpapers load *after* the page is opened, the list updates.
    final wallpaperState = ref.watch(wallpaperProvider);
    final allWallpapers = [
      ...wallpaperState.freeWallpapers,
      ...wallpaperState.premiumWallpapers,
    ];
    final Set<String> catSet = {};
    for (var wp in allWallpapers) {
      if (wp.category.trim().isNotEmpty) {
        catSet.add(wp.category.trim());
      } else {
        catSet.add(wp.autoCategory);
      }
    }
    _existingCategories = catSet.toList()..sort();
    
    // Ensure _selectedCategory is always valid in the dropdown items list
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
                  Text('Uploading to Cloudinary & Firebase...', style: TextStyle(color: Colors.white70)),
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
                  
                  // Premium Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.diamond, color: Colors.amber),
                            SizedBox(width: 12),
                            Text('Mark as Premium', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                        Switch(
                          value: _isPremium,
                          activeThumbColor: Colors.amber,
                          onChanged: (val) {
                            setState(() {
                              _isPremium = val;
                              if (val) _isSpecial = false; // mutually exclusive
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  // Special Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber),
                            SizedBox(width: 12),
                            Text('Mark as Special', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                        Switch(
                          value: _isSpecial,
                          activeThumbColor: Colors.amber,
                          onChanged: (val) {
                            setState(() {
                              _isSpecial = val;
                              if (val) _isPremium = false; // mutually exclusive
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // Price Field (Only if Special)
                  if (_isSpecial) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _priceController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Price (₹)',
                        labelStyle: const TextStyle(color: Colors.amber),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.currency_rupee, color: Colors.amber),
                      ),
                    ),
                  ],
                  
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
