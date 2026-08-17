import 'package:flutter/material.dart';

/// Centralized semantic color tokens for EH Home.
/// 
/// Contains exact palette definitions for both Dark Theme and Light Theme.
class EHColors {
  const EHColors._();

  // ---------------------------------------------------------------------------
  // DARK THEME PALETTE CONSTANTS
  // ---------------------------------------------------------------------------
  static const Color darkBgApp = Color(0xFF07111F);
  static const Color darkBgSecondary = Color(0xFF0B1728);
  static const Color darkSurfaceCard = Color(0xFF101F33);
  static const Color darkSurfaceElevated = Color(0xFF14263D);
  static const Color darkSurfaceNav = Color(0xFF0C192A);

  static const Color darkTextPrimary = Color(0xFFF4F7FB);
  static const Color darkTextSecondary = Color(0xFFAAB7C8);
  static const Color darkTextTertiary = Color(0xFF718198);
  static const Color darkSectionHeading = Color(0xFFAEBBCB);

  static const Color darkBorderSubtle = Color(0xFF1C3047);
  static const Color darkBorderControl = Color(0xFF26384E);

  static const Color darkBluePrimary = Color(0xFF3D82D6);
  static const Color darkBlueDarker = Color(0xFF2F6DB5);
  static const Color darkBlueSelectedBg = Color(0xFF17365B);
  static const Color darkBlueSelectedText = Color(0xFF78A9E5);

  static const Color darkGold = Color(0xFFF4C95D);
  static const Color darkGoldBright = Color(0xFFFFD86A);
  static const Color darkGoldContainer = Color(0xFF332C18);

  static const Color darkSuccess = Color(0xFF2DBE73);
  static const Color darkSuccessContainer = Color(0xFF123A2A);

  static const Color darkWarning = Color(0xFFF08A24);
  static const Color darkWarningContainer = Color(0xFF3A2815);

  static const Color darkError = Color(0xFFE05A47);
  static const Color darkErrorContainer = Color(0xFF3B1D1A);
  static const Color darkErrorText = Color(0xFFF06A55);

  static const Color darkNavInactiveIcon = Color(0xFF718198);
  static const Color darkNavInactiveLabel = Color(0xFF8C9AAD);
  static const Color darkNavSelectedIcon = Color(0xFF3D82D6);
  static const Color darkNavSelectedLabel = Color(0xFFDCEAFF);

  static const Color darkSwitchTrackOff = Color(0xFF26384E);
  static const Color darkSwitchThumbOff = Color(0xFFAAB7C8);
  static const Color darkSwitchTrackOn = Color(0xFF2F6DB5);
  static const Color darkSwitchThumbOn = Color(0xFFF4F7FB);

  static const Color darkChevron = Color(0xFF8FA0B5);
  static const Color darkHeaderAction = Color(0xFFD5DFEA);

  // Dark contextual icon containers
  static const Color darkIconBgBlue = Color(0xFF182B3D);
  static const Color darkIconFgBlue = Color(0xFF4D8ED1);
  static const Color darkIconBgGreen = Color(0xFF123A2A);
  static const Color darkIconFgGreen = Color(0xFF2DBE73);
  static const Color darkIconBgPlant = Color(0xFF192D2A);
  static const Color darkIconFgPlant = Color(0xFF55C58A);
  static const Color darkIconBgWater = Color(0xFF182E3A);
  static const Color darkIconFgWater = Color(0xFF5CA9C7);
  static const Color darkIconBgOrange = Color(0xFF3A2815);
  static const Color darkIconFgOrange = Color(0xFFF08A24);
  static const Color darkIconBgKitchen = Color(0xFF3A2818);
  static const Color darkIconFgKitchen = Color(0xFFF08A24);
  static const Color darkIconBgPurple = Color(0xFF251C3D);
  static const Color darkIconFgPurple = Color(0xFFA78BFA);

  // ---------------------------------------------------------------------------
  // LIGHT THEME PALETTE CONSTANTS (100% preserves existing light theme)
  // ---------------------------------------------------------------------------
  static const Color lightBgApp = Color(0xFFF6F8FC);
  static const Color lightBgSecondary = Color(0xFFFFFFFF);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightSurfaceNav = Color(0xFFFFFFFF);

  static const Color lightTextPrimary = Color(0xFF102448);
  static const Color lightTextSecondary = Color(0xFF65738C);
  static const Color lightTextTertiary = Color(0xFF8C9AAD);
  static const Color lightSectionHeading = Color(0xFF65738C);

  static const Color lightBorderSubtle = Color(0xFFE5EAF2);
  static const Color lightBorderControl = Color(0xFFD8E0EC);

  static const Color lightBluePrimary = Color(0xFF155CC8);
  static const Color lightBlueDarker = Color(0xFF104599);
  static const Color lightBlueSelectedBg = Color(0xFFE7EEFF);
  static const Color lightBlueSelectedText = Color(0xFF163E80);

  static const Color lightGold = Color(0xFFB88700);
  static const Color lightGoldBright = Color(0xFFDCAE45);
  static const Color lightGoldContainer = Color(0xFFFFF0DA);

  static const Color lightSuccess = Color(0xFF09944A);
  static const Color lightSuccessContainer = Color(0xFFE9F7EE);

  static const Color lightWarning = Color(0xFFE87A15);
  static const Color lightWarningContainer = Color(0xFFFFF4E5);

  static const Color lightError = Color(0xFFD92D20);
  static const Color lightErrorContainer = Color(0xFFFFE8E8);
  static const Color lightErrorText = Color(0xFFD92D20);

  static const Color lightNavInactiveIcon = Color(0xFF68758B);
  static const Color lightNavInactiveLabel = Color(0xFF68758B);
  static const Color lightNavSelectedIcon = Color(0xFF174F9F);
  static const Color lightNavSelectedLabel = Color(0xFF163E80);

  static const Color lightSwitchTrackOff = Color(0xFFE0E4EC);
  static const Color lightSwitchThumbOff = Color(0xFFFFFFFF);
  static const Color lightSwitchTrackOn = Color(0xFF155CC8);
  static const Color lightSwitchThumbOn = Color(0xFFFFFFFF);

  static const Color lightChevron = Color(0xFF65738C);
  static const Color lightHeaderAction = Color(0xFF102448);

  // Light contextual icon containers
  static const Color lightIconBgBlue = Color(0xFFEAF1FF);
  static const Color lightIconFgBlue = Color(0xFF155CC8);
  static const Color lightIconBgGreen = Color(0xFFE9F7EE);
  static const Color lightIconFgGreen = Color(0xFF09944A);
  static const Color lightIconBgPlant = Color(0xFFEDE9FF);
  static const Color lightIconFgPlant = Color(0xFF7A3DD5);
  static const Color lightIconBgWater = Color(0xFFE5F1FF);
  static const Color lightIconFgWater = Color(0xFF1956A8);
  static const Color lightIconBgOrange = Color(0xFFFFF4E5);
  static const Color lightIconFgOrange = Color(0xFFE87A15);
  static const Color lightIconBgKitchen = Color(0xFFFFEAE8);
  static const Color lightIconFgKitchen = Color(0xFFE87A15);
  static const Color lightIconBgPurple = Color(0xFFF3ECFF);
  static const Color lightIconFgPurple = Color(0xFF7A3DD5);
}
