
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  final display = await screenRetriever.getPrimaryDisplay();
  final screenSize = display.size;

  // Window aspect ratio.
  const contentRatio = 3.0;

  // Initial window scale.
  const initialScale = 0.3;

  // Minimum and maximum window scales.
  const minimumScale = 0.2;
  const maximumScale = 0.3;

  // Calculate maximum dimensions while preserving aspect ratio.
  final maxWidth = math.min(
    screenSize.width * maximumScale,
    screenSize.height * 0.8 * contentRatio,
  );

  final maxHeight = maxWidth / contentRatio;

  // Calculate minimum dimensions.
  final minWidth = math.min(
    screenSize.width * minimumScale,
    maxWidth,
  );

  final minHeight = minWidth / contentRatio;

  // Calculate initial dimensions.
  final initialWidth = (screenSize.width * initialScale)
      .clamp(minWidth, maxWidth)
      .toDouble();

  final initialHeight = initialWidth / contentRatio;

  final windowSize = Size(initialWidth, initialHeight);

  // Configure transparent, frameless window.
  await windowManager.setAsFrameless();
  await windowManager.setBackgroundColor(Colors.transparent);
  await windowManager.setHasShadow(false);

  // Enable resizing.
  await windowManager.setResizable(true);

  // Set minimum dimensions.
  await windowManager.setMinimumSize(
    Size(minWidth, minHeight),
  );

  // Set maximum dimensions.
  await windowManager.setMaximumSize(
    Size(maxWidth, maxHeight),
  );

  // Maintain aspect ratio during resizing.
  await windowManager.setAspectRatio(contentRatio);

  // Set initial window size.
  await windowManager.setSize(windowSize);

  await windowManager.center();
  await windowManager.show();

  runApp(const SashaRadioApp());
}

class SashaRadioApp extends StatelessWidget {
  const SashaRadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sasha Radio',
      home: RadioScreen(),
    );
  }
}

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  // Play button interaction states.
  bool isHovered = false;
  bool isPressed = false;

  // Determine which image should currently be displayed.
  String get playButtonImage {
    if (isPressed) {
      return 'assets/playbut_pressed.png';
    }

    if (isHovered) {
      return 'assets/playbut_hovered.png';
    }

    return 'assets/playbut.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          // Scale interactive elements with window dimensions.
          final songFontSize = h * 0.14;
          final playButtonWidth = w * 0.24;

          return DragToResizeArea(
            resizeEdgeSize: 10,
            child: Stack(
              children: [
                // Background: radio artwork.
                Positioned.fill(
                  child: DragToMoveArea(
                    child: Image.asset(
                      'assets/chosen2.png',
                      fit: BoxFit.fill,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),

                // Foreground: mascot.
                Positioned(
                  left: w * -0.055,
                  top: h * 0.17,
                  width: w * 0.45,
                  height: h * 0.45,
                  child: Image.asset(
                    'assets/chosenMascot.png',
                    fit: BoxFit.contain,
                  ),
                ),

                // Song title.
                Positioned(
                  left: w * 0.35,
                  top: h * 0.31,
                  width: w * 0.50,
                  child: Text(
                    'Space Song',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 38, 38, 38),
                      fontSize: songFontSize,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

                // Play button with hover and pressed states.
                Positioned(
                  left: w * 0.12,
                  top: h * 0.71,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,

                    // Mouse enters button.
                    onEnter: (_) {
                      setState(() {
                        isHovered = true;
                      });
                    },

                    // Mouse leaves button.
                    onExit: (_) {
                      setState(() {
                        isHovered = false;
                        isPressed = false;
                      });
                    },

                    child: GestureDetector(
                      // Mouse button is pressed.
                      onTapDown: (_) {
                        setState(() {
                          isPressed = true;
                        });
                      },

                      // Mouse button is released.
                      onTapUp: (_) {
                        setState(() {
                          isPressed = false;
                        });
                      },

                      // Press is cancelled.
                      onTapCancel: () {
                        setState(() {
                          isPressed = false;
                        });
                      },

                      // Button clicked.
                      onTap: () {
                        debugPrint('PLAY BUTTON PRESSED');
                      },

                      // Smoothly transition between button images.
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,

                        child: Image.asset(
                          playButtonImage,
                          key: ValueKey(playButtonImage),
                          width: playButtonWidth,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
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
