import 'package:flutter/material.dart';

// ── Mock Entities ─────────────────────────────────────────────────────────────
// MockUser/MockStatus/mockStatuses remain in use by the status feature's
// reels_viewer_screen.dart; the map-specific mocks (MockMapMarker,
// mockMapMarkers, mockGroups) were removed once the map feature switched to
// live MapUser/MapGroup data.

class MockUser {
  const MockUser({
    required this.id,
    required this.name,
    required this.initial,
    this.avatarUrl,
    required this.isOnline,
    required this.locationLabel,
    required this.avatarBgColor,
  });

  final String id;
  final String name;
  final String initial;
  final String? avatarUrl;
  final bool isOnline;
  final String locationLabel;
  final Color avatarBgColor;
}

class MockStatus {
  const MockStatus({
    required this.id,
    required this.author,
    required this.mediaUrl,
    required this.caption,
    required this.timestamp,
    required this.likeCount,
    required this.commentCount,
  });

  final String id;
  final MockUser author;
  final String mediaUrl;
  final String caption;
  final DateTime timestamp;
  final int likeCount;
  final int commentCount;
}

// ── Seed Data ─────────────────────────────────────────────────────────────────

final MockUser mockUserYou = MockUser(
  id: 'u1',
  name: 'You',
  initial: 'Y',
  avatarUrl:
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&q=80',
  isOnline: true,
  locationLabel: 'Zamalek, Cairo',
  avatarBgColor: const Color(0xFF607D8B),
);

final MockUser mockUserAhmed = MockUser(
  id: 'u4',
  name: 'Ahmed',
  initial: 'A',
  avatarUrl:
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&q=80',
  isOnline: false,
  locationLabel: 'Doqi, Cairo',
  avatarBgColor: const Color(0xFF546E7A),
);

final MockUser mockUserOmar = MockUser(
  id: 'u5',
  name: 'Omar Hassan',
  initial: 'O',
  avatarUrl:
      'https://images.unsplash.com/photo-1463453091185-61582044d556?w=200&q=80',
  isOnline: true,
  locationLabel: 'Near Zamalek, Cairo',
  avatarBgColor: const Color(0xFF00796B),
);

final List<MockStatus> mockStatuses = [
  MockStatus(
    id: 's1',
    author: mockUserYou,
    mediaUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&q=80',
    caption: 'Good morning! 🌅',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    likeCount: 14,
    commentCount: 3,
  ),
  MockStatus(
    id: 's2',
    author: mockUserOmar,
    mediaUrl:
        'https://images.unsplash.com/photo-1463453091185-61582044d556?w=600&q=80',
    caption: 'Status & Explore ✨',
    timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    likeCount: 31,
    commentCount: 7,
  ),
  MockStatus(
    id: 's3',
    author: mockUserAhmed,
    mediaUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600&q=80',
    caption: 'Cairo nights 🌙',
    timestamp: DateTime.now().subtract(const Duration(hours: 12)),
    likeCount: 8,
    commentCount: 1,
  ),
];
