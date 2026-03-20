// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode; 
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _storagePath = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadStoragePath();
  }

  Future<void> _loadStoragePath() async {
    final directory = await getApplicationDocumentsDirectory();
    setState(() {
      _storagePath = "${directory.path}/DocEase/Docs";
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode;
    Color textColor = isDark ? Colors.white : const Color(0xFF1A1C2E);
    Color subTextColor = isDark ? Colors.white54 : Colors.black54;
    Color iconColor = isDark ? Colors.white70 : Colors.blueGrey;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        children: [
          // REPLACE PROFILE WITH APP LOGO / BRANDING
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.description_rounded, // Document icon for branding
                    size: 60,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "DocEase",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  "Smart Document Scanner & Editor",
                  style: TextStyle(color: subTextColor, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // APPEARANCE SECTION
          _buildSectionHeader("Appearance"),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: iconColor),
            title: Text("Dark Mode", style: TextStyle(color: textColor)),
            subtitle: Text(
              isDark ? "Optimized for low light" : "Optimized for daylight",
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
            trailing: Switch(
              value: isDark,
              activeColor: Colors.blueAccent,
              onChanged: (value) => widget.onThemeChanged(value),
            ),
          ),

          const SizedBox(height: 25),

          // GENERAL & SUPPORT
          _buildSectionHeader("Support"),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.help_outline_rounded, color: iconColor),
            title: Text("How to use", style: TextStyle(color: textColor)),
            trailing: Icon(Icons.chevron_right, color: subTextColor),
            onTap: () {
              // Placeholder for tutorial or help dialog
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.privacy_tip_outlined, color: iconColor),
            title: Text("Privacy Policy", style: TextStyle(color: textColor)),
            trailing: Icon(Icons.chevron_right, color: subTextColor),
            onTap: () {},
          ),

          const SizedBox(height: 25),

          // SYSTEM INFORMATION
          _buildSectionHeader("System Information"),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline, color: iconColor),
            title: Text("App Version", style: TextStyle(color: textColor)),
            trailing: Text(
              "5.0.0 (Thesis Build)",
              style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.storage_rounded, color: iconColor),
            title: Text("Internal Storage", style: TextStyle(color: textColor)),
            subtitle: Text(
              _storagePath,
              style: TextStyle(color: subTextColor, fontSize: 10),
            ),
          ),

          const SizedBox(height: 40),

          // DANGER ZONE
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.05),
              foregroundColor: Colors.redAccent,
              elevation: 0,
              side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _showClearDataDialog(context);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_sweep_rounded),
                SizedBox(width: 10),
                Text("Clear All App Data", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
            letterSpacing: 1.1,
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Colors.black12),
      ],
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Data?"),
        content: const Text("This will permanently delete all scanned documents. This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Clear Everything", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}