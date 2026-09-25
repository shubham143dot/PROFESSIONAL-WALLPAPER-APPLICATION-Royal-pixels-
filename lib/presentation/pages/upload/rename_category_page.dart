import 'package:royal_pixels/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/safe_tap.dart';

import '../../../core/di/service_locator.dart';
import '../../../domain/usecases/rename_category_usecase.dart';
import '../../providers/wallpaper_provider.dart';

class RenameCategoryPage extends ConsumerStatefulWidget {
  final String? initialCategory;
  const RenameCategoryPage({super.key, this.initialCategory});

  @override
  ConsumerState<RenameCategoryPage> createState() => _RenameCategoryPageState();
}

class _RenameCategoryPageState extends ConsumerState<RenameCategoryPage> {
  final _newCategoryController = TextEditingController();

  List<String> _existingCategories = [];
  String? _selectedCategory;
  bool _isRenaming = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  void _rename() async {
    SafeTap.run('admin_rename_category', () async {
      final newName = _newCategoryController.text.trim();
      if (_selectedCategory == null || newName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.pleaseSelectACategoryAndEnterANewName)),
          );
        }
        return;
      }

      setState(() => _isRenaming = true);

      try {
        final renameUseCase = sl<RenameCategoryUseCase>();
        final result = await renameUseCase(_selectedCategory!, newName);

        result.fold(
          (failure) => throw Exception(failure.message),
          (_) {
            // Success!
            ref.read(wallpaperProvider.notifier).loadWallpapers();

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Category renamed successfully to $newName! 🚀')),
            );
            context.pop();
          },
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isRenaming = false);
      }
    });
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        if (existing.isNotEmpty &&
            existing[0].toLowerCase() == existing[0] &&
            cat.isNotEmpty &&
            cat[0].toUpperCase() == cat[0]) {
          catMap[lowerKey] = cat;
        }
      }
    }
    _existingCategories = catMap.values.toList()..sort();

    List<String> dropDownItems = [..._existingCategories];

    if (_selectedCategory == null && dropDownItems.isNotEmpty) {
      _selectedCategory = dropDownItems.first;
    } else if (_selectedCategory != null &&
        !dropDownItems.contains(_selectedCategory)) {
      if (dropDownItems.isNotEmpty) {
        _selectedCategory = dropDownItems.first;
      } else {
        _selectedCategory = null;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(AppLocalizations.of(context)!.renameCategory,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isRenaming
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.amber),
                  SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.updatingCategoriesAndProperties,
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(AppLocalizations.of(context)!.selectAnExistingCategoryToRenameThisWillUpdateTheCategoryPropertyOfAllAssociatedWallpapersAndMigrateItsCoverImageIfOneExists,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Select Category',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: dropDownItems.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c,
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // New category term
                  TextField(
                    controller: _newCategoryController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'New Category Name',
                      labelStyle: const TextStyle(color: Colors.amber),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.amber)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.amber)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.amber, width: 2)),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Rename Button
                  ElevatedButton(
                    onPressed: _rename,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(AppLocalizations.of(context)!.renameCategory,
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
