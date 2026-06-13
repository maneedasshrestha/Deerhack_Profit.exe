import 'dart:io';

import 'package:flutter/material.dart';

/// One circular avatar used everywhere a person is shown: their chosen photo if
/// they set one, otherwise a gradient circle with their initials — the same
/// gradient the profile header has always used, now in one place.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    this.photoPath,
    this.size = 96,
    this.fontSize,
  });

  final String initials;
  final String? photoPath;
  final double size;

  /// Override the initials text size. Defaults to ~38% of [size].
  final double? fontSize;

  static const _gradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF9F5BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  bool get _hasPhoto {
    final p = photoPath;
    return p != null && p.isNotEmpty && File(p).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _hasPhoto;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasPhoto ? null : _gradient,
        image: hasPhoto
            ? DecorationImage(image: FileImage(File(photoPath!)), fit: BoxFit.cover)
            : null,
      ),
      child: hasPhoto
          ? null
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: fontSize ?? size * 0.38,
                  letterSpacing: -0.5,
                ),
              ),
            ),
    );
  }
}
