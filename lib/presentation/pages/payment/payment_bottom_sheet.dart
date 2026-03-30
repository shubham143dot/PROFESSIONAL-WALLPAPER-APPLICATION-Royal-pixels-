import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/repositories/payment_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/diamond_loader.dart';

/// Shows the QR payment bottom sheet and returns `true` if payment was confirmed.
Future<bool> showPaymentBottomSheet(
  BuildContext context, {
  required String wallpaperId,
  required String wallpaperTitle,
  required double amount,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PaymentBottomSheet(
      wallpaperId: wallpaperId,
      wallpaperTitle: wallpaperTitle,
      amount: amount,
    ),
  );
  return result ?? false;
}

class PaymentBottomSheet extends ConsumerStatefulWidget {
  final String wallpaperId;
  final String wallpaperTitle;
  final double amount;

  const PaymentBottomSheet({
    super.key,
    required this.wallpaperId,
    required this.wallpaperTitle,
    required this.amount,
  });

  @override
  ConsumerState<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends ConsumerState<PaymentBottomSheet>
    with SingleTickerProviderStateMixin {
  final _txnController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  /// The screenshot file selected by the user (optional but encouraged).
  File? _screenshotFile;
  bool _isUploadingScreenshot = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _txnController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─── Screenshot Picker ───────────────────────────────────────────────────

  Future<void> _pickScreenshot(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1080,
      );
      if (picked == null) return;
      setState(() => _screenshotFile = File(picked.path));
    } catch (e) {
      _showError('Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e');
    }
  }

  void _showScreenshotSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Payment Screenshot',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _sourceOption(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickScreenshot(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 12),
              _sourceOption(
                icon: Icons.camera_alt_rounded,
                label: 'Take a Photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickScreenshot(ImageSource.camera);
                },
              ),
              if (_screenshotFile != null) ...[
                const SizedBox(height: 12),
                _sourceOption(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove Screenshot',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _screenshotFile = null);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.amber,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color == Colors.redAccent ? Colors.redAccent : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Payment Submission ──────────────────────────────────────────────────

  Future<void> _confirmPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider).user;
    if (user == null) {
      _showError('Please login to unlock this wallpaper.');
      return;
    }

    setState(() => _isSubmitting = true);

    final repo = sl<PaymentRepository>();
    String? uploadedScreenshotUrl;

    // Upload screenshot if one was selected
    if (_screenshotFile != null) {
      setState(() => _isUploadingScreenshot = true);
      final uploadResult = await repo.uploadPaymentScreenshot(
        userId: user.uid,
        wallpaperId: widget.wallpaperId,
        localFilePath: _screenshotFile!.path,
      );
      setState(() => _isUploadingScreenshot = false);

      uploadResult.fold(
        (failure) {
          // Screenshot upload failed — show warning but don't block submission
          _showWarning('Screenshot upload failed. Proceeding without it.');
        },
        (url) => uploadedScreenshotUrl = url,
      );
    }

    final result = await repo.submitManualPayment(
      userId: user.uid,
      wallpaperId: widget.wallpaperId,
      amount: widget.amount,
      txnId: _txnController.text.trim(),
      wallpaperTitle: widget.wallpaperTitle,
      screenshotUrl: uploadedScreenshotUrl,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) => _showError(failure.message),
      (_) async {
        // ── Save unlocked wallpaper ID to SharedPreferences ──────────────────
        final prefs = await SharedPreferences.getInstance();
        final ids = prefs.getStringList('downloaded_wallpaper_ids') ?? [];
        if (!ids.contains(widget.wallpaperId)) {
          ids.add(widget.wallpaperId);
          await prefs.setStringList('downloaded_wallpaper_ids', ids);
        }
        if (mounted) Navigator.of(context).pop(true);
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        height: screenHeight * 0.92,
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F0F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),

                      // Title
                      _buildHeader(),

                      const SizedBox(height: 24),

                      // QR Code card
                      _buildQrCard(),

                      const SizedBox(height: 28),

                      // Step instructions
                      _buildSteps(),

                      const SizedBox(height: 28),

                      // Transaction ID input
                      _buildTxnInput(),

                      const SizedBox(height: 20),

                      // Screenshot upload
                      _buildScreenshotUpload(),

                      const SizedBox(height: 24),

                      // Confirm button
                      _buildConfirmButton(),

                      const SizedBox(height: 16),

                      // Cancel button
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Crown icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFCC00), Color(0xFFFF8C00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFCC00).withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.workspace_premium, color: Colors.black, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          widget.wallpaperTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Price badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFCC00), Color(0xFFFF8C00)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            '₹${widget.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFCC00).withValues(alpha: 0.2),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // PhonePe label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5F259F),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PhonePe',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // QR Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/qr_code.png',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2, size: 72, color: Color(0xFF5F259F)),
                      SizedBox(height: 8),
                      Text(
                        'QR code not found.\nAdd assets/qr_code.png',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Scan with any UPI app',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps() {
    final steps = [
      ('1', 'Open any UPI app', 'GPay, PhonePe, Paytm, etc.'),
      ('2', 'Scan the QR code above', 'Point your camera at the QR'),
      ('3', 'Pay ₹${widget.amount.toStringAsFixed(0)}', 'Confirm the payment in your app'),
      ('4', 'Enter Transaction ID below', 'Copy the 12-digit UTR/Txn ID'),
      ('5', 'Upload payment screenshot', 'Take a screenshot of the success page'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to pay:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFCC00), Color(0xFFFF8C00)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          step.$1,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.$2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            step.$3,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTxnInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaction / UTR ID',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _txnController,
          style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 1),
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(30),
          ],
          onChanged: (val) {
            final upper = val.toUpperCase();
            if (val != upper) {
              _txnController.value = _txnController.value.copyWith(
                text: upper,
                selection: TextSelection.collapsed(offset: upper.length),
              );
            }
          },
          decoration: InputDecoration(
            hintText: 'e.g. T2025031412345678',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            prefixIcon: const Icon(Icons.receipt_long_outlined, color: Colors.amber),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFFCC00), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter the Transaction ID from your UPI app';
            }
            if (value.trim().length < 6) {
              return 'Transaction ID seems too short (min 6 chars)';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white30, size: 14),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Find the UTR/Transaction ID in your UPI app\'s payment receipt',
                style: TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Screenshot Upload Widget ────────────────────────────────────────────

  Widget _buildScreenshotUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Payment Screenshot',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Recommended',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Screenshot preview or upload tap area
        GestureDetector(
          onTap: _showScreenshotSourceDialog,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            height: _screenshotFile != null ? 200 : 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _screenshotFile != null
                    ? const Color(0xFFFFCC00).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.12),
                width: _screenshotFile != null ? 1.5 : 1,
                style: _screenshotFile != null
                    ? BorderStyle.solid
                    : BorderStyle.solid,
              ),
            ),
            child: _screenshotFile != null
                ? _buildScreenshotPreview()
                : _buildUploadPlaceholder(),
          ),
        ),

        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.white30, size: 13),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                'Upload a screenshot of your payment confirmation for faster verification',
                style: TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFCC00), Color(0xFFFF8C00)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.upload_rounded, color: Colors.black, size: 24),
        ),
        const SizedBox(height: 10),
        const Text(
          'Tap to upload screenshot',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Gallery or Camera',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildScreenshotPreview() {
    return Stack(
      children: [
        // Screenshot thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.file(
            _screenshotFile!,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),

        // Dark overlay for controls
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
        ),

        // ✓ checkmark top-right
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
        ),

        // Change / remove bottom row
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _previewActionChip(
                icon: Icons.edit_rounded,
                label: 'Change',
                onTap: _showScreenshotSourceDialog,
              ),
              const SizedBox(width: 10),
              _previewActionChip(
                icon: Icons.delete_rounded,
                label: 'Remove',
                color: Colors.redAccent,
                onTap: () => setState(() => _screenshotFile = null),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Confirm Button ──────────────────────────────────────────────────────

  Widget _buildConfirmButton() {
    // Determine label depending on state
    final String label = _isUploadingScreenshot
        ? 'Uploading Screenshot…'
        : 'Confirm Payment & Unlock';

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _confirmPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isSubmitting
                ? const LinearGradient(colors: [Color(0xFF444444), Color(0xFF333333)])
                : const LinearGradient(
                    colors: [Color(0xFFFFCC00), Color(0xFFFF8C00)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isSubmitting
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFFFFCC00).withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isSubmitting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: DiamondLoader(
                          size: 22,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_open_rounded, color: Colors.black, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Confirm Payment & Unlock',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
