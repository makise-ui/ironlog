import 'package:flutter/material.dart';
import '../../today/presentation/widgets/ai_assistant_sheet.dart';

/// Full-screen AI Coach & Assistant screen with immersive chat view,
/// live tool tracking, interactive questions, and complete workout controls.
class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: AiAssistantSheet(isFullScreen: true),
    );
  }
}
