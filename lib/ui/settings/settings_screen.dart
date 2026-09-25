import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/store.dart';
import 'config_share_section.dart';
import 'feedback_section.dart';
import 'help_screen.dart';
import 'income_items_section.dart';
import 'settings_sections_extra.dart';
import 'settings_sections_rules.dart';
import 'settings_sections_time.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConfigShareSection(store: store),
          PayPeriodSection(store: store),
          WorkHoursSection(store: store),
          WageTableSection(store: store),
          IncomeItemsSection(store: store),
          HolidaysSection(store: store),
          BreakRulesSection(store: store),
          OvertimeBracketsSection(store: store),
          GpsSection(store: store),
          const FeedbackSection(),
          const HelpEntrySection(),
          LateRuleSection(store: store),
        ],
      ),
    );
  }
}
