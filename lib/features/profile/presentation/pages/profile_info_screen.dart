import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';
import '../data/mock_profile_data.dart';

class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({super.key});

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late FocusNode _nameFocusNode;
  late FocusNode _bioFocusNode;

  @override
  void initState() {
    super.initState();
    final user = MockProfileData.currentUser;
    _nameController = TextEditingController(text: user.name);
    _bioController = TextEditingController(text: user.bio);

    _nameFocusNode = FocusNode();
    _bioFocusNode = FocusNode();

    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) {
        if (_nameController.text == user.name) {
          _nameController.clear();
          setState(() {});
        }
      } else {
        if (_nameController.text.isEmpty) {
          _nameController.text = user.name;
          setState(() {});
        }
      }
    });

    _bioFocusNode.addListener(() {
      if (_bioFocusNode.hasFocus) {
        if (_bioController.text == user.bio) {
          _bioController.clear();
          setState(() {});
        }
      } else {
        if (_bioController.text.isEmpty) {
          _bioController.text = user.bio;
          setState(() {});
        }
      }
    });
    
    _nameController.addListener(() => setState(() {}));
    _bioController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _nameFocusNode.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = MockProfileData.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'profile_info_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: CachedNetworkImageProvider(user.avatarUrl),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            // TextFields
            TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              style: TextStyle(
                color: _nameController.text == user.name ? Colors.grey : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'profile_name_hint'.tr(),
                labelStyle: TextStyle(color: Colors.grey[800]),
                floatingLabelStyle: TextStyle(color: Colors.grey[800]),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _bioController,
              focusNode: _bioFocusNode,
              style: TextStyle(
                color: _bioController.text == user.bio ? Colors.grey : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'profile_about_hint'.tr(),
                labelStyle: TextStyle(color: Colors.grey[800]),
                floatingLabelStyle: TextStyle(color: Colors.grey[800]),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                context.go(AppRouterName.profileVerificationWelcome);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'profile_save_info_btn'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
