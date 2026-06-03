import 'package:flutter/material.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common/app_text.dart';

class ExploreTabPage extends StatelessWidget {
  const ExploreTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppText.title('Explore', color: context.colors.tx2),
    );
  }
}
