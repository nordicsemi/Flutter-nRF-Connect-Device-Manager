import 'package:flutter/material.dart';
import 'package:mcumgr_flutter_example/src/view/custom_group_manager/custom_group_manager_widget.dart';

class CustomGroupManagerPage extends StatelessWidget {
  const CustomGroupManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Group Manager')),
      body: const CustomGroupManagerWidget(),
    );
  }
}
