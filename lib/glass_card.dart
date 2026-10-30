import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget widget;
  final Color? color;

  const GlassCard({super.key, required this.widget, this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // FIXED: Changed from BorderRadiusGeometry to BorderRadius
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: widget,
          ),
        ),
      ),
    );
  }
}
