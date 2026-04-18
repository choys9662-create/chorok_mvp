import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ChorokSheetHandle extends StatelessWidget {
  const ChorokSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: context.appBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
