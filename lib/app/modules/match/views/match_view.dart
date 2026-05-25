import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/match_controller.dart';

class MatchView extends GetView<MatchController> {
  const MatchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('경기')),
      body: Center(
        child: Text(
          '경기 페이지',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
