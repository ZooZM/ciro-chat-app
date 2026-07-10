import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool messageNotification = true;
  bool callNotification = true;
  bool statusNotification = true;
  bool appNotification = true;
  bool vibrate = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'notif_settings_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 17,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        children: [
          _buildToggleItem(
            'notif_message'.tr(),
            messageNotification,
            (val) => setState(() => messageNotification = val),
          ),
          _buildToggleItem(
            'notif_call'.tr(),
            callNotification,
            (val) => setState(() => callNotification = val),
          ),
          _buildToggleItem(
            'notif_status'.tr(),
            statusNotification,
            (val) => setState(() => statusNotification = val),
          ),
          _buildToggleItem(
            'notif_app'.tr(),
            appNotification,
            (val) => setState(() => appNotification = val),
          ),
          _buildToggleItem(
            'notif_vibrate'.tr(),
            vibrate,
            (val) => setState(() => vibrate = val),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Colors.black87),
          ),
          trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF4CA440),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[300],
          ),
        ),
      ),
    );
  }
}
