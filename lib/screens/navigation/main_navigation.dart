import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../documents/documents_screen.dart';
import '../settings/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isDarkMode = true; // Shared Theme State

  void _toggleTheme(bool value) {
    setState(() => _isDarkMode = value);
  }

  // Helper to get the title for the shared AppBar
  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0: return "DocEase";
      case 1: return "My Documents";
      case 2: return "Settings";
      default: return "DocEase";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    
    // Theme Colors
    final Color bgColor = isDark ? const Color(0xFF0B0E2C) : const Color(0xFFF0F4F8);
    final Color appBarColor = isDark ? const Color(0xFF061F33) : const Color(0xFFD1D9E6);
    final Color navBarColor = isDark ? const Color(0xFF0D1128) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1A1C2E);

    return Scaffold(
      backgroundColor: bgColor,
      // THE SHARED APP BAR
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
        backgroundColor: appBarColor,
        elevation: 0,
        actions: _currentIndex == 1 ? [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: () {
              // This requires a GlobalKey if you want to trigger 
              // the refresh inside DocumentsScreen from here.
            },
          )
        ] : null,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(isDarkMode: _isDarkMode),
          DocumentsScreen(isDarkMode: _isDarkMode),
          SettingsScreen(
            isDarkMode: _isDarkMode, 
            onThemeChanged: _toggleTheme,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        decoration: BoxDecoration(
          color: navBarColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_filled, "Home"),
            _buildNavItem(1, Icons.folder_rounded, "Docs"),
            _buildNavItem(2, Icons.settings_rounded, "Settings"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    Color activeColor = Colors.blueAccent;
    Color inactiveColor = _isDarkMode ? Colors.grey : Colors.blueGrey.withOpacity(0.6);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? activeColor : inactiveColor, size: 28),
          Text(
            label, 
            style: TextStyle(
              color: isSelected ? activeColor : inactiveColor, 
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
            )
          ),
        ],
      ),
    );
  }
}