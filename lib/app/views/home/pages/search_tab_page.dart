import 'package:flutter/material.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/common/app_text.dart';

class SearchTabPage extends StatelessWidget {
  const SearchTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppText.title('Search', color: context.colors.tx2),
    );
  }
}
