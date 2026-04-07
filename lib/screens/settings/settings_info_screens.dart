import 'package:flutter/material.dart';

/// --------------------------------------------------
/// HOW TO USE SCREEN
/// --------------------------------------------------
class HowToUseScreen extends StatelessWidget {
  final bool isDarkMode;

  const HowToUseScreen({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF1A1C2E);
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade50;

    // Updated steps based on the new detailed workflow
    final List<Map<String, dynamic>> steps = [
      {
        "icon": Icons.add_a_photo_rounded,
        "title": "1. Add Your Images",
        "desc": "Use the Camera button to 'Capture Document' directly, or go to Quick Actions to 'Import from Gallery'."
      },
      {
        "icon": Icons.image_search_rounded,
        "title": "2. Manage & Edit Selection",
        "desc": "Review your selected images. You can add more, clear the list, or remove them individually. Tap the Edit button to crop, rotate, or adjust brightness. Click the Check mark when done, then press 'Scan'."
      },
      {
        "icon": Icons.dashboard_customize_rounded,
        "title": "3. Choose a Template",
        "desc": "Select a template (None, Essay, Letter, Report, Memo) and preview it in A4, Short, or Long sizes. You can also build 'Custom' templates with headers, footers, and backgrounds, and save them for future use!"
      },
      {
        "icon": Icons.text_format_rounded,
        "title": "4. Edit Your Document",
        "desc": "Rename your file and start editing. Switch between Mobile and Print views. Use formatting tools like Bold, Italic, Underline, and Alignments. You can also customize your Font Family and Size."
      },
      {
        "icon": Icons.save_alt_rounded,
        "title": "5. Save & Export",
        "desc": "Click the Save icon when finished. You can save it as an in-app project to continue editing later, or export it directly as a TXT, DOCX, or PDF file."
      },
      {
        "icon": Icons.folder_copy_rounded,
        "title": "6. Manage Documents",
        "desc": "Go to 'Docs' or 'My Documents' to view your files. You can open or delete exported files, or resume editing any unfinished projects saved directly to the app."
      },
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "How to Use",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: steps.length,
        separatorBuilder: (context, index) => const SizedBox(height: 15),
        itemBuilder: (context, index) {
          final step = steps[index];
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step["icon"],
                    color: Colors.blueAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step["title"],
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step["desc"],
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// --------------------------------------------------
/// PRIVACY POLICY SCREEN
/// --------------------------------------------------
class PrivacyPolicyScreen extends StatelessWidget {
  final bool isDarkMode;

  const PrivacyPolicyScreen({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF1A1C2E);
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "Privacy Policy",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildSectionTitle("1. Data Collection", textColor),
            _buildParagraph(
                "DocEase prioritizes your privacy. We do not collect, transmit, or store your scanned documents on any external servers. All document processing and storage occur locally on your device.",
                subTextColor),
            const SizedBox(height: 20),
            _buildSectionTitle("2. App Permissions", textColor),
            _buildParagraph(
                "To function correctly, DocEase requires access to your device's Camera (to scan documents) and Storage (to save and retrieve your exported PDFs and images). We do not use these permissions for any other purpose.",
                subTextColor),
            const SizedBox(height: 20),
            _buildSectionTitle("3. Third-Party Services", textColor),
            _buildParagraph(
                "We do not sell, trade, or otherwise transfer your personal information to outside parties. We do not include third-party analytics or tracking software that monitors your scanned content.",
                subTextColor),
            const SizedBox(height: 20),
            _buildSectionTitle("4. Changes to this Policy", textColor),
            _buildParagraph(
                "We may update our Privacy Policy from time to time. We will notify you of any changes by updating the \"Effective Date\" at the top of this policy.",
                subTextColor),
            const SizedBox(height: 40),
            Center(
              child: Text(
                "If you have any questions, contact us at\nthesiscs4@gmail.com",
                textAlign: TextAlign.center,
                style: TextStyle(color: subTextColor, fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text, Color subTextColor) {
    return Text(
      text,
      style: TextStyle(
        color: subTextColor,
        fontSize: 15,
        height: 1.6,
      ),
    );
  }
}