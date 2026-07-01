// lib/features/auth/screens/terms_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/logo_widget.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: LogoWidget(size: 48, darkText: true)),
            const SizedBox(height: 32),
            const _Section(
              title: 'Terms & Conditions',
              content: '''
Last updated: January 2025

By using the Jireta Loans application, you agree to the following terms:

1. LOAN ELIGIBILITY
You must be a Filipino citizen, at least 18 years of age, with a valid government-issued ID and verifiable income to apply for a loan.

2. LOAN TERMS
All loans carry a flat 20% interest rate on the principal amount. Loan amounts range from ₱3,000 to ₱500,000. Repayment schedules are daily, weekly, or monthly as determined at approval.

3. PENALTY POLICY
A grace period of 30 days applies. After 30 days of non-payment, a penalty of 20% of the total payable is applied per month of overdue.

4. CO-MAKER REQUIREMENT
Every loan application requires a co-maker who provides their full name, relationship to the borrower, and digital signature.

5. KYC REQUIREMENT
Valid government ID (front and back), a selfie, and employment information are required before any loan can be processed.

6. PAYMENTS
Payments may be made via GCash, Maya, QR, Cash (rider collection), or Bank Transfer as configured by the system.

7. DATA USE
Your personal and financial information is encrypted (AES-256-GCM) and is used solely for loan processing, credit assessment, and regulatory compliance.

8. TERMINATION
Jireta Loans & Credit Corp Inc. reserves the right to suspend accounts found in violation of these terms.
''',
            ),
            const SizedBox(height: 32),
            const _Section(
              title: 'Privacy Policy',
              content: '''
Jireta Loans & Credit Corp Inc. is committed to protecting your personal information.

INFORMATION WE COLLECT
• Identity information (name, government ID, photo)
• Contact information (email, phone, address)
• Financial information (income, employer, loan history)
• Location data (for rider collection assignments)
• Device information (for push notifications)

HOW WE USE YOUR INFORMATION
• Processing loan applications and payments
• Sending notifications and reminders
• Credit risk assessment
• Compliance with BSP and applicable laws

DATA SECURITY
All personally identifiable and financial data is encrypted at rest using AES-256-GCM. Access is role-controlled and fully audited.

YOUR RIGHTS
You may request access, correction, or deletion of your data by contacting our office.

CONTACT
Jireta Loans & Credit Corp Inc.
Email: privacy@jiretaloans.com
''',
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('I Understand'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;
  const _Section({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          content.trim(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.7,
                fontSize: 14,
              ),
        ),
      ],
    );
  }
}