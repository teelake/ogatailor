import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches the device's phone dialer with the given number.
/// Returns true if launched, false otherwise.
/// Works for all users - no plan restriction (core workflow utility).
Future<bool> launchPhoneCall(String phoneNumber) async {
  final trimmed = phoneNumber.trim();
  if (trimmed.isEmpty) return false;

  final uri = Uri.parse('tel:$trimmed');
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}
