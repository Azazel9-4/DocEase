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

  // Helper to get the current screen with a unique Key for the AnimatedSwitcher
  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0: 
        return HomeScreen(key: const ValueKey(0), isDarkMode: _isDarkMode);
      case 1: 
        return DocumentsScreen(key: const ValueKey(1), isDarkMode: _isDarkMode);
      case 2: 
        return SettingsScreen(
          key: const ValueKey(2), 
          isDarkMode: _isDarkMode, 
          onThemeChanged: _toggleTheme,
        );
      default: 
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    
    // Theme Colors
    final Color bgColor = isDark ? const Color(0xFF0B0E2C) : const Color(0xFFF0F4F8);
    final Color appBarColor = isDark ? const Color(0xFF061F33) : const Color(0xFFD1D9E6);
    final Color navBarColor = isDark ? const Color(0xFF0D1128) : Colors.blueGrey.withOpacity(0.1);
    final Color textColor = isDark ? Colors.white : const Color(0xFF1A1C2E);

    final double systemNavHeight = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
        backgroundColor: appBarColor,
        elevation: 0,
        actions: _currentIndex == 1 ? [] : null,
      ),
      
      // 1. REPLACED IndexedStack with AnimatedSwitcher for a minimal cross-fade
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _getCurrentScreen(),
      ),
      
      bottomNavigationBar: Container(
        height: 70,
        margin: EdgeInsets.fromLTRB(
          20, 
          0, 
          20, 
          systemNavHeight > 0 ? systemNavHeight + 10 : 20,
        ), 
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
    Color inactiveColor = _isDarkMode ? Colors.grey : Colors.blueGrey;

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Ensures the whole area is clickable
      onTap: () => setState(() => _currentIndex = index),
      child: SizedBox(
        width: 70, // Fixed width to prevent jumping during transitions
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 2. ADDED AnimatedScale for a subtle, fluid pop effect
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack, // Gives it a tiny, natural bounce
              child: Icon(icon, color: isSelected ? activeColor : inactiveColor, size: 26),
            ),
            const SizedBox(height: 4),
            // 3. ADDED AnimatedDefaultTextStyle to smoothly transition font weights/colors
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor, 
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}