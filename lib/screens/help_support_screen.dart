import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/base_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  // Support email
  static const String _supportEmail = 'mcabrerasos@miatracker.com';

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      currentRoute: '/help',
      title: 'Help & Support',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildQuickHelpSection(),
            const SizedBox(height: 24),
            _buildFAQSection(),
            const SizedBox(height: 24),
            _buildContactSection(),
            const SizedBox(height: 24),
            _buildContactForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2B5F8C), Color(0xFF6B8E3D)],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.support_agent,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'How can we help you?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'We\'re here to answer your questions and help you get the most out of MIA Tracker.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickHelpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Help',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B5F8C),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickHelpCard(
                icon: Icons.video_library,
                title: 'Video Tutorials',
                description: 'Learn step by step',
                color: const Color(0xFF6B8E3D),
                onTap: () => _showComingSoonDialog('Video Tutorials'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickHelpCard(
                icon: Icons.menu_book,
                title: 'Documentation',
                description: 'Complete guides',
                color: const Color(0xFF2B5F8C),
                onTap: () => _showComingSoonDialog('Documentation'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickHelpCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B5F8C),
          ),
        ),
        const SizedBox(height: 16),
        _buildFAQItem(
          question: 'How do I add a new product to inventory?',
          answer:
          'Go to the Inventory screen and press the "+" button. Fill in the required fields such as name, quantity, and location. You can also scan the barcode to add products faster.',
        ),
        _buildFAQItem(
          question: 'How does the QR code scanner work?',
          answer:
          'Press the scanner icon at the top of the screen. Point the camera at the product\'s QR code or barcode. The system will automatically search for the product in your inventory.',
        ),
        _buildFAQItem(
          question: 'What are low stock alerts?',
          answer:
          'Alerts notify you when a product reaches its configured minimum quantity. Only administrators and supervisors receive these email alerts.',
        ),
        _buildFAQItem(
          question: 'How do I request a product restock?',
          answer:
          'On the inventory screen, select the low-stock product and press "Request Restock". Supervisors and administrators can approve or reject these requests.',
        ),
        _buildFAQItem(
          question: 'How do I add products to the shopping cart?',
          answer:
          'When you scan a product or view its details, you can select the quantity and press "Add to Cart". The cart validates available stock and prevents adding more than what\'s available.',
        ),
        _buildFAQItem(
          question: 'What\'s the difference between Cart and Marketplace Cart?',
          answer:
          'Shopping Cart is for internal inventory transfers. Marketplace Cart is for ordering products from external suppliers through the marketplace.',
        ),
      ],
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6B8E3D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.help_outline,
              color: Color(0xFF6B8E3D),
              size: 20,
            ),
          ),
          title: Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contact Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B5F8C),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildContactItem(
                  icon: Icons.email,
                  title: 'Support Email',
                  subtitle: _supportEmail,
                  color: const Color(0xFF2B5F8C),
                  onTap: () => _launchEmail(),
                ),
                const Divider(height: 24),
                _buildContactItem(
                  icon: Icons.access_time,
                  title: 'Business Hours',
                  subtitle: 'Monday to Friday\n8:00 AM - 6:00 PM (GMT-6)',
                  color: const Color(0xFF6B8E3D),
                  onTap: null,
                ),
                const Divider(height: 24),
                _buildContactItem(
                  icon: Icons.language,
                  title: 'Website',
                  subtitle: 'www.miatracker.com',
                  color: const Color(0xFF2B5F8C),
                  onTap: () => _launchWebsite(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Send us a Message',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B5F8C),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Fill out the form and we\'ll get back to you as soon as possible',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      hintText: 'e.g. Issue with inventory',
                      prefixIcon: const Icon(Icons.subject),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a subject';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      hintText: 'Describe your problem or question...',
                      prefixIcon: const Icon(Icons.message),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    maxLines: 6,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your message';
                      }
                      if (value.trim().length < 10) {
                        return 'Message must be at least 10 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendEmail,
                    icon: _isSending
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.send),
                    label: Text(_isSending ? 'Sending...' : 'Send Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E3D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You can also send an email directly to $_supportEmail',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSending = true);

    try {
      final subject = Uri.encodeComponent(_subjectController.text.trim());
      final body = Uri.encodeComponent(_messageController.text.trim());
      final emailUri = 'mailto:$_supportEmail?subject=$subject&body=$body';

      final uri = Uri.parse(emailUri);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);

        if (mounted) {
          _subjectController.clear();
          _messageController.clear();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Opening email client...'),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF6B8E3D),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw 'Cannot open email client';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Copy Email',
              textColor: Colors.white,
              onPressed: () => _copyEmailToClipboard(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _launchEmail() async {
    try {
      final uri = Uri.parse('mailto:$_supportEmail');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _copyEmailToClipboard();
      }
    } catch (e) {
      _copyEmailToClipboard();
    }
  }

  Future<void> _launchWebsite() async {
    try {
      final uri = Uri.parse('https://www.miatracker.com');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Cannot open browser';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening website: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyEmailToClipboard() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.copy, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Email copied: $_supportEmail'),
              ),
            ],
          ),
          backgroundColor: Color(0xFF2B5F8C),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF2B5F8C)),
            const SizedBox(width: 12),
            Expanded(child: Text(feature)),
          ],
        ),
        content: Text('$feature will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(color: Color(0xFF6B8E3D)),
            ),
          ),
        ],
      ),
    );
  }
}