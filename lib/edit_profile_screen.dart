import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'services/user_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialDisplayName;
  final String initialBio;
  final String? initialPhotoUrl;

  const EditProfileScreen({
    super.key,
    required this.initialDisplayName,
    required this.initialBio,
    this.initialPhotoUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _idController;
  late final TextEditingController _bioController;
  late final TextEditingController _websiteController;
  late final TextEditingController _birthdayController;

  final ImagePicker _picker = ImagePicker();
  final List<TextEditingController> _trackedControllers = [];

  String? _category;
  String? _gender;
  DateTime? _birthday;
  String? _photoUrl;
  String? _pickedPhotoPath;
  Uint8List? _pickedPhotoBytes;

  bool _isHydrating = false;
  bool _hasUserEdited = false;
  bool _isLoadingProfile = true;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  static const List<String> _categories = [
    'Digital creator',
    'Public figure',
    'Musician',
    'Gamer',
    'Fashion',
    'Education',
    'Fitness',
    'Food',
    'Business',
    'Other',
  ];

  static const List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDisplayName);
    _idController = TextEditingController();
    _bioController = TextEditingController(text: widget.initialBio);
    _websiteController = TextEditingController();
    _birthdayController = TextEditingController();
    _photoUrl = widget.initialPhotoUrl;

    _trackedControllers.addAll([
      _nameController,
      _idController,
      _bioController,
      _websiteController,
    ]);
    for (final controller in _trackedControllers) {
      controller.addListener(_markEdited);
    }
    _loadProfileData();
  }

  @override
  void dispose() {
    for (final controller in _trackedControllers) {
      controller.removeListener(_markEdited);
    }
    _nameController.dispose();
    _idController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  void _markEdited() {
    if (!_isHydrating) {
      _hasUserEdited = true;
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final data = await UserService.instance.currentUserProfileData();
      if (!mounted) return;

      if (!_hasUserEdited) {
        _isHydrating = true;
        _nameController.text = _readString(data, const [
          'name',
          'displayName',
        ], fallback: widget.initialDisplayName);
        _idController.text = _readString(data, const ['username']);
        _bioController.text = _readString(data, const [
          'bio',
        ], fallback: widget.initialBio);
        _websiteController.text = _readString(data, const ['website']);

        _category = _normaliseOption(
          _readString(data, const ['category']),
          _categories,
        );
        _gender = _normaliseOption(
          _readString(data, const ['gender']),
          _genders,
        );
        _birthday = _readBirthday(data['birthday']);
        _birthdayController.text = _formatBirthday(_birthday);
        _photoUrl = _readString(data, const [
          'photoURL',
          'photoUrl',
        ], fallback: widget.initialPhotoUrl ?? '');
        if (_photoUrl?.isEmpty == true) {
          _photoUrl = null;
        }
        _isHydrating = false;
      }

      setState(() => _isLoadingProfile = false);
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isLoadingProfile || _isSaving || _isUploadingImage) return;

    setState(() => _isSaving = true);
    final updatedName = _nameController.text.trim();
    final updatedUsername = _idController.text.trim();
    final updatedBio = _bioController.text.trim();
    final updatedWebsite = _websiteController.text.trim();

    try {
      await UserService.instance.updateProfile(
        name: updatedName,
        username: updatedUsername,
        bio: updatedBio,
        website: updatedWebsite,
        category: _category,
        gender: _gender,
        birthday: _birthday,
        photoUrl: _photoUrl,
      );

      if (mounted) {
        Navigator.pop(context, {
          'displayName': updatedName,
          'bio': updatedBio,
          'photoUrl': _photoUrl ?? '',
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save profile.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF15151A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _birthday) {
      setState(() {
        _birthday = picked;
        _birthdayController.text = _formatBirthday(picked);
        _hasUserEdited = true;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
      );
      if (pickedFile == null) return;

      setState(() {
        _isUploadingImage = true;
        _pickedPhotoPath = pickedFile.path;
        _pickedPhotoBytes = null;
        _hasUserEdited = true;
      });

      final String downloadUrl;
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        downloadUrl = await UserService.instance.uploadProfileImageBytes(bytes);
        if (mounted) {
          setState(() => _pickedPhotoBytes = bytes);
        }
      } else {
        downloadUrl = await UserService.instance.uploadProfileImage(
          File(pickedFile.path),
        );
      }

      if (mounted) {
        setState(() {
          _photoUrl = downloadUrl;
          _pickedPhotoPath = null;
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo ready. Press Save to update profile.'),
            backgroundColor: Color(0xFF1F8F5F),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pickedPhotoPath = null;
          _pickedPhotoBytes = null;
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  String? _normaliseOption(String value, List<String> options) {
    if (value.isEmpty) return null;
    for (final option in options) {
      if (option.toLowerCase() == value.toLowerCase()) {
        return option;
      }
    }
    return null;
  }

  DateTime? _readBirthday(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  String _formatBirthday(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_isLoadingProfile && !_isSaving && !_isUploadingImage;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton(
              onPressed: canSave ? _saveProfile : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white30,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.redAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF2D55).withValues(alpha: 0.10),
                    Colors.black,
                    const Color(0xFF08080A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              30 + MediaQuery.of(context).padding.bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarSection(),
                    const SizedBox(height: 22),
                    _buildSectionCard(
                      children: [
                        _buildInputField(
                          label: 'Nickname',
                          controller: _nameController,
                          hintText: 'Add your nickname',
                        ),
                        _buildInputField(
                          label: 'Likeehit ID',
                          controller: _idController,
                          helperText: 'This is your public creator username',
                          hintText: 'username',
                        ),
                        _buildInputField(
                          label: 'Bio',
                          controller: _bioController,
                          maxLines: 3,
                          hintText: 'Add a bio to your profile',
                        ),
                        _buildInputField(
                          label: 'Website',
                          controller: _websiteController,
                          hintText: 'https://',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSectionCard(
                      children: [
                        _buildDropdownField(
                          label: 'Category',
                          value: _category,
                          items: _categories,
                          hintText: 'Select category',
                          onChanged: (val) => setState(() {
                            _category = val;
                            _hasUserEdited = true;
                          }),
                        ),
                        _buildDropdownField(
                          label: 'Gender',
                          value: _gender,
                          items: _genders,
                          hintText: 'Select gender',
                          onChanged: (val) => setState(() {
                            _gender = val;
                            _hasUserEdited = true;
                          }),
                        ),
                        GestureDetector(
                          onTap: _selectBirthday,
                          child: AbsorbPointer(
                            child: _buildInputField(
                              label: 'Birthday',
                              controller: _birthdayController,
                              hintText: 'Select your birthday',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        _isLoadingProfile
                            ? 'Loading saved profile...'
                            : 'Changes are applied only after you press Save.',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoadingProfile)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                color: Colors.redAccent,
                backgroundColor: Colors.transparent,
                minHeight: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    ImageProvider? imageProvider;
    if (_pickedPhotoBytes != null) {
      imageProvider = MemoryImage(_pickedPhotoBytes!);
    } else if (_pickedPhotoPath != null && !kIsWeb) {
      imageProvider = FileImage(File(_pickedPhotoPath!));
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_photoUrl!);
    }

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploadingImage ? null : _pickAndUploadImage,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Color(0xFFFF2D75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.26),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF16161A),
                    backgroundImage: imageProvider,
                    child: imageProvider == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: Colors.white54,
                            size: 52,
                          )
                        : null,
                  ),
                ),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.26),
                  ),
                  child: _isUploadingImage
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Change photo',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? helperText,
    String? hintText,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            cursorColor: Colors.redAccent,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.white30),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.redAccent.withValues(alpha: 0.75),
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.34),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required String hintText,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.34),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(13),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  hintText,
                  style: const TextStyle(color: Colors.white30),
                ),
                isExpanded: true,
                dropdownColor: const Color(0xFF17171C),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white54,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
