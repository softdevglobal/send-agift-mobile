import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small solid tag naming a section of a page, as on the website.
class SectionTag extends StatelessWidget {
  const SectionTag({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 10, 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusBoxSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.boxLabel.copyWith(
                fontSize: 10.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
