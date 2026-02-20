import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:profanity_filter/profanity_filter.dart';

import '../../core/router.dart';
import '../../repositories/profile_repository.dart';

// ─── Interest definition ──────────────────────────────────────────────────────

class _Interest {
  const _Interest({
    required this.id,
    required this.label,
    required this.emoji,
    required this.description,
  });
  final String id;
  final String label;
  final String emoji;
  final String description;
}

const _kInterests = [
  _Interest(
    id: 'food',
    label: 'Food & Dining',
    emoji: '🍽️',
    description: 'Restaurants, cafés, takeout',
  ),
  _Interest(
    id: 'retail',
    label: 'Retail',
    emoji: '🛍️',
    description: 'Shops, boutiques, markets',
  ),
  _Interest(
    id: 'services',
    label: 'Services',
    emoji: '🔧',
    description: 'Repair, cleaning, trades',
  ),
  _Interest(
    id: 'health',
    label: 'Health & Wellness',
    emoji: '💪',
    description: 'Gyms, clinics, spas',
  ),
  _Interest(
    id: 'entertainment',
    label: 'Entertainment',
    emoji: '🎭',
    description: 'Venues, activities, events',
  ),
  _Interest(
    id: 'beauty',
    label: 'Beauty',
    emoji: '💅',
    description: 'Salons, barbers, cosmetics',
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // Shared
  final _repo = ProfileRepository();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // Step 1 – Profile
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _nameFocus = FocusNode();
  File? _avatarFile;
  final _imagePicker = ImagePicker();

  // Step 2 – Location
  bool _locationGranted = false;
  bool _locationRequesting = false;

  // Step 3 – Interests
  final Set<String> _selectedInterests = {};

  // Animation controller for page entrance
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _usernameFocus.dispose();
    _nameFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goToPage(int page) {
    _fadeCtrl.reset();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = page);
    _fadeCtrl.forward();
  }

  void _back() => _goToPage(_currentPage - 1);

  void _next() {
    if (_currentPage == 0) {
      final error = _validateUsername(_usernameController.text);
      if (error != null) {
        _showUsernameError(error);
        return;
      }
    }
    _goToPage(_currentPage + 1);
  }

  Future<void> _skipAll() async {
    final error = _validateUsername(_usernameController.text);
    if (error != null) {
      _showUsernameError(error);
      return;
    }
    _finish(skip: true);
  }

  // Returns an error string if invalid, null if valid.
  static final _profanityFilter = ProfanityFilter();

  String? _validateUsername(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Username is required.';
    if (v.contains(' ')) return 'Username cannot contain spaces.';
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(v)) {
      return 'Only letters, numbers, and . _ - are allowed.';
    }
    if (v.length < 3) return 'Username must be at least 3 characters.';
    if (v.length > 30) return 'Username must be 30 characters or fewer.';
    if (_profanityFilter.hasProfanity(v)) {
      return 'That username isn\'t allowed. Please choose another.';
    }
    return null;
  }

  void _showUsernameError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _usernameFocus.requestFocus();
  }

  Future<void> _finish({bool skip = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _repo.saveProfile(
        username: _usernameController.text.trim(),
        fullName: _nameController.text,
        city: _cityController.text,
        avatarFile: _avatarFile,
        interests: _selectedInterests.toList(),
      );
      await _repo.completeOnboarding();
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Avatar picking ─────────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    final colorScheme = Theme.of(context).colorScheme;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outline.withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Choose photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(Icons.camera_alt_rounded,
                      color: colorScheme.onPrimaryContainer),
                ),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Icon(Icons.photo_library_rounded,
                      color: colorScheme.onSecondaryContainer),
                ),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              if (_avatarFile != null) ...[
                const Divider(height: 8),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.errorContainer,
                    child: Icon(Icons.delete_outline_rounded,
                        color: colorScheme.onErrorContainer),
                  ),
                  title: const Text('Remove photo'),
                  onTap: () {
                    setState(() => _avatarFile = null);
                    Navigator.pop(ctx);
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  // ── Location ───────────────────────────────────────────────────────────────

  Future<void> _requestLocation() async {
    setState(() => _locationRequesting = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError('Location services are disabled on this device.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError(
          'Location permission is permanently denied. '
          'Enable it in Settings to use nearby features.',
        );
        return;
      }

      if (permission == LocationPermission.denied) return;

      setState(() => _locationGranted = true);
      await Future.delayed(const Duration(milliseconds: 600));
      _next();
    } finally {
      if (mounted) setState(() => _locationRequesting = false);
    }
  }

  void _showLocationError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              currentPage: _currentPage,
              totalPages: 3,
              onBack: _currentPage > 0 ? _back : null,
              onSkip: _skipAll,
              isSaving: _isSaving,
            ),
            Expanded(
              child: FadeTransition(
                opacity: _fade,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _ProfileStep(
                      usernameController: _usernameController,
                      nameController: _nameController,
                      cityController: _cityController,
                      usernameFocus: _usernameFocus,
                      nameFocus: _nameFocus,
                      avatarFile: _avatarFile,
                      onPickAvatar: _pickAvatar,
                      onNext: _next,
                    ),
                    _LocationStep(
                      granted: _locationGranted,
                      requesting: _locationRequesting,
                      onRequest: _requestLocation,
                      onSkip: _next,
                    ),
                    _InterestsStep(
                      selected: _selectedInterests,
                      onToggle: (id) => setState(() {
                        _selectedInterests.contains(id)
                            ? _selectedInterests.remove(id)
                            : _selectedInterests.add(id);
                      }),
                      onDone: _finish,
                      isSaving: _isSaving,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top bar with progress + skip ─────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.currentPage,
    required this.totalPages,
    required this.onSkip,
    required this.isSaving,
    this.onBack,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback onSkip;
  final bool isSaving;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
      child: Row(
        children: [
          // Back button or spacer
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBack,
              tooltip: 'Back',
              style: IconButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
              ),
            )
          else
            const SizedBox(width: 48),

          // Step dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (i) {
                final active = i == currentPage;
                final done = i < currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(right: 6),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: done || active
                        ? colorScheme.primary
                        : colorScheme.outline.withAlpha(77),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          if (!isSaving)
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurface.withAlpha(153),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Skip all'),
            )
          else
            const SizedBox(width: 72),
        ],
      ),
    );
  }
}

// ─── Step 1: Profile ──────────────────────────────────────────────────────────

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.usernameController,
    required this.nameController,
    required this.cityController,
    required this.usernameFocus,
    required this.nameFocus,
    required this.avatarFile,
    required this.onPickAvatar,
    required this.onNext,
  });

  final TextEditingController usernameController;
  final TextEditingController nameController;
  final TextEditingController cityController;
  final FocusNode usernameFocus;
  final FocusNode nameFocus;
  final File? avatarFile;
  final VoidCallback onPickAvatar;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Let's set up your profile",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This helps personalise your experience. You can always change this later.',
                style: TextStyle(
                  fontSize: 14.5,
                  color: colorScheme.onSurface.withAlpha(153),
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),

          // Avatar picker
          GestureDetector(
            onTap: onPickAvatar,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(51),
                      width: 3,
                    ),
                    image: avatarFile != null
                        ? DecorationImage(
                            image: FileImage(avatarFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarFile == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 50,
                          color: colorScheme.onPrimaryContainer.withAlpha(179),
                        )
                      : null,
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 2.5,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onPickAvatar,
            child: Text(
              avatarFile == null ? 'Add photo' : 'Change photo',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Username field (required)
          TextField(
            controller: usernameController,
            focusNode: usernameFocus,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 30,
            // Strip spaces and disallowed characters as the user types
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]')),
            ],
            decoration: InputDecoration(
              labelText: 'Username *',
              hintText: 'e.g. jamiechen',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              helperText: 'Letters, numbers, and . _ - only',
              counterText: '', // hide the default "0/30" counter
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withAlpha(77),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.outline.withAlpha(51),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name field
          TextField(
            controller: nameController,
            focusNode: nameFocus,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Your name',
              hintText: 'e.g. Jamie Chen',
              prefixIcon: const Icon(Icons.badge_outlined),
              helperText: "How you'll appear to others",
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withAlpha(77),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.outline.withAlpha(51),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // City field
          TextField(
            controller: cityController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'City (optional)',
              hintText: 'e.g. Vancouver',
              prefixIcon: const Icon(Icons.location_city_outlined),
              helperText: 'Helps us show relevant local businesses',
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withAlpha(77),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.outline.withAlpha(51),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Continue button
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Continue'),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Location ─────────────────────────────────────────────────────────

class _LocationStep extends StatelessWidget {
  const _LocationStep({
    required this.granted,
    required this.requesting,
    required this.onRequest,
    required this.onSkip,
  });

  final bool granted;
  final bool requesting;
  final VoidCallback onRequest;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Illustration area
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon bubble
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: granted
                        ? colorScheme.primaryContainer
                        : colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    granted
                        ? Icons.location_on_rounded
                        : Icons.location_searching_rounded,
                    size: 58,
                    color: granted
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  granted
                      ? 'Location access granted!'
                      : 'Find businesses near you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  granted
                      ? "We'll show you businesses nearby and let you know how far away they are."
                      : "Allow location access to discover businesses in your neighbourhood and see distances at a glance.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface.withAlpha(153),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Feature pills
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _FeaturePill(
                      icon: Icons.near_me_rounded,
                      label: 'Nearby results',
                      colorScheme: colorScheme,
                    ),
                    _FeaturePill(
                      icon: Icons.straighten_rounded,
                      label: 'Distance info',
                      colorScheme: colorScheme,
                    ),
                    _FeaturePill(
                      icon: Icons.local_offer_rounded,
                      label: 'Local deals',
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Buttons
          if (granted) ...[
            FilledButton(
              onPressed: onSkip,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Continue'),
                ],
              ),
            ),
          ] else ...[
            FilledButton(
              onPressed: requesting ? null : onRequest,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              child: requesting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_outlined, size: 18),
                        SizedBox(width: 6),
                        Text('Allow Location Access'),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: requesting ? null : onSkip,
              child: Text(
                'Not now',
                style: TextStyle(
                  color: colorScheme.onSurface.withAlpha(128),
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(179),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withAlpha(38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withAlpha(204),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Interests ────────────────────────────────────────────────────────

class _InterestsStep extends StatelessWidget {
  const _InterestsStep({
    required this.selected,
    required this.onToggle,
    required this.onDone,
    required this.isSaving,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onDone;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Header
          Text(
            'What are you into?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick your interests and we\'ll show you the most relevant businesses first.',
            style: TextStyle(
              fontSize: 14.5,
              color: colorScheme.onSurface.withAlpha(153),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Interest grid
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              itemCount: _kInterests.length,
              itemBuilder: (context, i) {
                final interest = _kInterests[i];
                final isSelected = selected.contains(interest.id);
                return _InterestCard(
                  interest: interest,
                  selected: isSelected,
                  onTap: () => onToggle(interest.id),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Selection count hint
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: selected.isNotEmpty
                ? Padding(
                    key: const ValueKey('count'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${selected.length} selected',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('empty'), height: 10),
          ),

          // Done button
          FilledButton(
            onPressed: isSaving ? null : onDone,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            child: isSaving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected.isEmpty
                            ? Icons.arrow_forward_rounded
                            : Icons.check_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                          selected.isEmpty ? 'Skip for now' : 'Get Started'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _InterestCard extends StatelessWidget {
  const _InterestCard({
    required this.interest,
    required this.selected,
    required this.onTap,
  });

  final _Interest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest.withAlpha(102),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? colorScheme.primary
              : colorScheme.outline.withAlpha(51),
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(38),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(interest.emoji,
                      style: const TextStyle(fontSize: 28)),
                  if (selected)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_rounded,
                          size: 14, color: colorScheme.onPrimary),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interest.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    interest.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected
                          ? colorScheme.onPrimaryContainer.withAlpha(179)
                          : colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}