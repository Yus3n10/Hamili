import 'package:flutter/material.dart';

import 'widgets/admin_access_log_tab.dart';
import 'widgets/admin_overview_tab.dart';
import 'widgets/admin_privacy_footer.dart';
import 'widgets/admin_testers_tab.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Overview'), Tab(text: 'Testers'), Tab(text: 'Access log')],
          ),
        ),
        body: const Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [AdminOverviewTab(), AdminTestersTab(), AdminAccessLogTab()],
              ),
            ),
            SafeArea(top: false, child: AdminPrivacyFooter()),
          ],
        ),
      ),
    );
  }
}
