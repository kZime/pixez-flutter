/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'dart:io';

class Constants {
  static const String no_h = 'assets/images/h_long.jpg';
  static String tagName = "0.9.109";
  static const isGooglePlay =
      bool.fromEnvironment("IS_GOOGLEPLAY", defaultValue: false);
  static int type = 0;
  static String? code_verifier = null;

  /// Enables the existing Material desktop preview on macOS/Windows.
  static final bool desktopPreview =
      const bool.fromEnvironment('DESKTOP_PREVIEW') &&
      (Platform.isMacOS || Platform.isWindows);

  /// Enables the opt-in Fluent preview on macOS without changing its default
  /// Material entry point. DESKTOP_PREVIEW deliberately takes precedence.
  static final bool macosFluentPreview =
      const bool.fromEnvironment('MACOS_FLUENT_PREVIEW') &&
      Platform.isMacOS &&
      !desktopPreview;

  /// Selects the Fluent entry point for a platform while keeping the preview
  /// surface independent from the normal Windows Fluent app.
  static bool shouldUseFluent({
    required bool isWindows,
    required bool macosFluentPreview,
    required bool desktopPreview,
  }) => !desktopPreview && (isWindows || macosFluentPreview);

  static final bool isFluent = shouldUseFluent(
    isWindows: Platform.isWindows,
    macosFluentPreview: macosFluentPreview,
    desktopPreview: desktopPreview,
  );
}
