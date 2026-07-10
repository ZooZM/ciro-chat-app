import 'package:flutter/material.dart';

class UserProfile {
  final String name;
  final String bio;
  final String ciroId;
  final String avatarUrl;
  final int completionPercentage;

  const UserProfile({
    required this.name,
    required this.bio,
    required this.ciroId,
    required this.avatarUrl,
    required this.completionPercentage,
  });
}

class WalletInfo {
  final String totalBalance;
  final String currentBalance;
  final String currency;

  const WalletInfo({
    required this.totalBalance,
    required this.currentBalance,
    required this.currency,
  });
}

class ThemePreview {
  final String id;
  final String thumbnailPath;

  const ThemePreview({
    required this.id,
    required this.thumbnailPath,
  });
}

class ChatColorOption {
  final String id;
  final Color color;

  const ChatColorOption({
    required this.id,
    required this.color,
  });
}

class BackgroundOption {
  final String id;
  final String imagePath;
  final bool isCustomAdd;

  const BackgroundOption({
    required this.id,
    required this.imagePath,
    this.isCustomAdd = false,
  });
}

class MockProfileData {
  static const UserProfile currentUser = UserProfile(
    name: 'Ahmed Mohamed',
    bio: 'Living the moment',
    ciroId: 'CIR123456',
    avatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026704d',
    completionPercentage: 60,
  );

  static const WalletInfo currentWallet = WalletInfo(
    totalBalance: '12,450.50',
    currentBalance: '12,120.',
    currency: 'SAR',
  );

  static const List<ThemePreview> mockThemes = [
    ThemePreview(id: 'theme1', thumbnailPath: 'assets/images_ui/mock_theme_1.png'),
    ThemePreview(id: 'theme2', thumbnailPath: 'assets/images_ui/mock_theme_2.png'),
    ThemePreview(id: 'theme3', thumbnailPath: 'assets/images_ui/mock_theme_3.png'),
    ThemePreview(id: 'theme4', thumbnailPath: 'assets/images_ui/mock_theme_4.png'),
  ];

  static const List<ChatColorOption> mockColors = [
    ChatColorOption(id: 'c1', color: Colors.green),
    ChatColorOption(id: 'c2', color: Colors.teal),
    ChatColorOption(id: 'c3', color: Colors.blue),
    ChatColorOption(id: 'c4', color: Colors.indigo),
    ChatColorOption(id: 'c5', color: Colors.purple),
    ChatColorOption(id: 'c6', color: Colors.deepPurple),
    ChatColorOption(id: 'c7', color: Colors.pink),
    ChatColorOption(id: 'c8', color: Colors.red),
    ChatColorOption(id: 'c9', color: Colors.orange),
    ChatColorOption(id: 'c10', color: Colors.brown),
    ChatColorOption(id: 'c11', color: Colors.blueGrey),
    ChatColorOption(id: 'c12', color: Colors.grey),
    ChatColorOption(id: 'c13', color: Colors.black),
    ChatColorOption(id: 'c14', color: Colors.deepOrange),
  ];

  static const List<BackgroundOption> mockBackgrounds = [
    BackgroundOption(id: 'add', imagePath: '', isCustomAdd: true),
    BackgroundOption(id: 'bg1', imagePath: 'assets/images_ui/mock_bg_1.png'),
    BackgroundOption(id: 'bg2', imagePath: 'assets/images_ui/mock_bg_2.png'),
    BackgroundOption(id: 'bg3', imagePath: 'assets/images_ui/mock_bg_3.png'),
    BackgroundOption(id: 'bg4', imagePath: 'assets/images_ui/mock_bg_4.png'),
  ];
}
