
import 'dart:async';
import 'dart:math' as math;

import 'package:desktop_music_player/services/streaming_service.dart';
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

  bool eqIsHovered = false;
  bool eqIsPressed = false;

  bool xIsHovered = false;
  bool xIsPressed = false;

  bool isMinHovered = false;
  bool isMinPressed = false;

  // LiveKit streaming service.
  late final StreamingService streamingService;

  bool isConnecting = false;
  bool isListening = false;

  @override
  void initState() {
    super.initState();
    streamingService = StreamingService();
  }

  // Connect or disconnect from the radio.
  Future<void> toggleListening() async {
    if (isConnecting) return;

    setState(() {
      isConnecting = true;
    });

    try {
      if (isListening) {
        await streamingService.disconnect();

        if (mounted) {
          setState(() {
            isListening = false;
          });
        }
      } else {
        await streamingService.connectAsListener();

        if (mounted) {
          setState(() {
            isListening = true;
          });
        }
      }
    } catch (error) {
      debugPrint('LiveKit connection error: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isConnecting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(streamingService.dispose());
    super.dispose();
  }

  String get minButtonImage {
    if (isMinPressed) {
      return 'assets/min_pressed.png';
    }

    if (isMinHovered) {
      return 'assets/min_hover.png';
    }

    return 'assets/min.png';
  }

  // Determine which close button image should be displayed.
  String get xButtonImage {
    if (xIsPressed) {
      return 'assets/xbut_pressed.png';
    }

    if (xIsHovered) {
      return 'assets/xbut_hover.png';
    }

    return 'assets/xbut.png';
  }

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

  String get eqButtonImage {
    if (eqIsPressed) {
      return 'assets/eqbut_pressed.png';
    }

    if (eqIsHovered) {
      return 'assets/eqbut_hover.png';
    }

    return 'assets/eqbut.png';
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
          final minButtonWidth = w * 0.053;

          return DragToResizeArea(
            resizeEdgeSize: 10,
            child: Stack(
              children: [
                // Background: radio artwork.
                Positioned.fill(
                  child: DragToMoveArea(
                    child: Image.asset(
                      'assets/player.png',
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

                // Close window button.
                Positioned(
                  right: w * 0.030,
                  top: h * 0.05,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) {
                      setState(() {
                        xIsHovered = true;
                      });
                    },
                    onExit: (_) {
                      setState(() {
                        xIsHovered = false;
                        xIsPressed = false;
                      });
                    },
                    child: GestureDetector(
                      onTapDown: (_) {
                        setState(() {
                          xIsPressed = true;
                        });
                      },
                      onTapUp: (_) {
                        setState(() {
                          xIsPressed = false;
                        });
                      },
                      onTapCancel: () {
                        setState(() {
                          xIsPressed = false;
                        });
                      },
                      onTap: () async {
                        await windowManager.close();
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Image.asset(
                          xButtonImage,
                          key: ValueKey(xButtonImage),
                          height: h * 0.12,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // Minimise window button.
                Positioned(
                  left: w * 0.821,
                  top: h * 0.054,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) {
                      setState(() {
                        isMinHovered = true;
                      });
                    },
                    onExit: (_) {
                      setState(() {
                        isMinHovered = false;
                        isMinPressed = false;
                      });
                    },
                    child: GestureDetector(
                      onTapDown: (_) {
                        setState(() {
                          isMinPressed = true;
                        });
                      },
                      onTapUp: (_) {
                        setState(() {
                          isMinPressed = false;
                        });
                      },
                      onTapCancel: () {
                        setState(() {
                          isMinPressed = false;
                        });
                      },
                      onTap: () async {
                        await windowManager.minimize();
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Image.asset(
                          minButtonImage,
                          key: ValueKey(minButtonImage),
                          width: minButtonWidth,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // Equaliser button.
                Positioned(
                  left: w * 0.027,
                  top: h * 0.71,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) {
                      setState(() {
                        eqIsHovered = true;
                      });
                    },
                    onExit: (_) {
                      setState(() {
                        eqIsHovered = false;
                        eqIsPressed = false;
                      });
                    },
                    child: GestureDetector(
                      onTapDown: (_) {
                        setState(() {
                          eqIsPressed = true;
                        });
                      },
                      onTapUp: (_) {
                        setState(() {
                          eqIsPressed = false;
                        });
                      },
                      onTapCancel: () {
                        setState(() {
                          eqIsPressed = false;
                        });
                      },
                      onTap: () {
                        debugPrint('EQUALISER BUTTON PRESSED');
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Image.asset(
                          eqButtonImage,
                          key: ValueKey(eqButtonImage),
                          width: w * 0.08,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // Play button: connects to or disconnects from LiveKit.
                Positioned(
                  left: w * 0.12,
                  top: h * 0.71,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) {
                      setState(() {
                        isHovered = true;
                      });
                    },
                    onExit: (_) {
                      setState(() {
                        isHovered = false;
                        isPressed = false;
                      });
                    },
                    child: GestureDetector(
                      onTapDown: (_) {
                        setState(() {
                          isPressed = true;
                        });
                      },
                      onTapUp: (_) {
                        setState(() {
                          isPressed = false;
                        });
                      },
                      onTapCancel: () {
                        setState(() {
                          isPressed = false;
                        });
                      },
                      onTap: toggleListening,
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


            
// Red LIVE indicator - only visible when broadcaster is live.
Positioned(
  left: w * 0.191,
  top: h * 0.054,
  child: ValueListenableBuilder<bool>(
    valueListenable: streamingService.isBroadcasterLive,
    builder: (context, isLive, child) {
      if (!isLive) {
        return const SizedBox.shrink();
      }

      return Image.asset(
        'assets/live.png',
        height: h * 0.12,
        fit: BoxFit.contain,
      );
    },
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
