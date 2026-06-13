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

  /// Resolves the photo to an ImageProvider: a remote Storage URL, a local file
  /// that still exists, or null → fall back to the gradient-initials avatar.
  ImageProvider? get _image {
    final p = photoPath;
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('http')) return NetworkImage(p);
    return File(p).existsSync() ? FileImage(File(p)) : null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: image == null ? _gradient : null,
        image: image == null
            ? null
            : DecorationImage(image: image, fit: BoxFit.cover),
      ),
      child: image != null
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
