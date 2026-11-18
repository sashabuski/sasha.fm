
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
  const maximumScale = 0.8;

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

class _RadioScreenState extends State<RadioScreen>
    with SingleTickerProviderStateMixin {  // Play button interaction states.
  bool isHovered = false;
  bool isPressed = false;

  bool eqIsHovered = false;
  bool eqIsPressed = false;

  bool xIsHovered = false;
  bool xIsPressed = false;

  bool windowIsHovered = false;
bool windowIsPressed = false;
  bool isPowerOn = false;
  bool isMinHovered = false;
  bool isMinPressed = false;

  // LiveKit streaming service.
  late final StreamingService streamingService;
late AnimationController mascotController;
late Animation<double> mascotOpacity;
  bool isConnecting = false;
  bool isListening = false;

  @override
void initState() {
  super.initState();

  streamingService = StreamingService();

  mascotController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  mascotOpacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 0.8),
      weight: 15,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.8, end: 0.15),
      weight: 10,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.15, end: 0.8),
      weight: 15,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.8, end: 0.3),
      weight: 10,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.3, end: 0.8),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: ConstantTween(0.8),
      weight: 30,
    ),
  ]).animate(mascotController);
}

  // Connect or disconnect from the radio.
 Future<void> toggleListening() async {
  if (isPowerOn) {
    // Turn radio OFF.
    setState(() {
      isPowerOn = false;
      isListening = false;
    });

    mascotController.reset();

    await streamingService.disconnect();

  } else {
    // Turn radio ON.
    setState(() {
      isPowerOn = true;
    });

    // Start mascot flicker animation.
    mascotController.forward(from: 0);

    try {
      setState(() {
        isConnecting = true;
      });

      await streamingService.connectAsListener();

      setState(() {
        isListening = true;
      });

    } catch (e) {
      debugPrint('Connection error: $e');

      if (!mounted) return;

      // Connection failed: turn radio OFF.
      setState(() {
        isPowerOn = false;
        isListening = false;
      });

      mascotController.reset();

    } finally {
      if (mounted) {
        setState(() {
          isConnecting = false;
        });
      }
    }
  }
}

Future<void> toggleWindowSize() async {

  // Get screen dimensions.
  final display = await screenRetriever.getPrimaryDisplay();
  final screenSize = display.size;

  // Match your existing main() configuration.
  const contentRatio = 3.0;
  const minimumScale = 0.2;
  const maximumScale = 0.8;

  // Calculate maximum dimensions.
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

  // Get current window dimensions.
  final currentSize = await windowManager.getSize();

  // Calculate distance between two sizes.
  double distance(Size a, Size b) {
    final dx = a.width - b.width;
    final dy = a.height - b.height;

    return dx * dx + dy * dy;
  }

  final minSize = Size(minWidth, minHeight);
  final maxSize = Size(maxWidth, maxHeight);

  // Determine which target is furthest away.
  final distanceToMin = distance(currentSize, minSize);
  final distanceToMax = distance(currentSize, maxSize);

  final targetSize = distanceToMax >= distanceToMin
      ? maxSize
      : minSize;

  // Resize the window.
  await windowManager.setSize(targetSize);

  // Reposition it centrally.
  await windowManager.center();
}
 @override
void dispose() {
  mascotController.dispose();
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
  String get windowButtonImage {
  if (windowIsPressed) {
    return 'assets/WINDOWBUTPRESSED.png';
  }

  if (windowIsHovered) {
    return 'assets/WINDOWBUTHOVERED.png';
  }

  return 'assets/WINDOWBUT.png';
}

  // Determine which image should currently be displayed.
  String get onButtonImage {
  if (isPowerOn) {
    if (isPressed) return 'assets/pinkonbutpressed.png';
    if (isHovered) return 'assets/pinkonbuthovered.png';
    return 'assets/pinkonbutdefault.png';
  }

  if (isPressed) return 'assets/onbutpressed.png';
  if (isHovered) return 'assets/onbuthovered.png';

  return 'assets/onbutdefault.png';
}

  String get eqButtonImage {
  // Device OFF.
  if (!isPowerOn) {
    return 'assets/eqbutoff.png';
  }

  // Device ON.
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
          final minButtonWidth = w * 0.047;

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
  left: w * -0.07,
  top: h * 0.3,
  width: w * 0.4,
  height: h * 0.4,
  child: AnimatedBuilder(
    animation: mascotOpacity,
    builder: (context, child) {
      return Opacity(
        opacity: isPowerOn ? mascotOpacity.value : 0.0,
        child: child,
      );
    },
    child: Image.asset(
      'assets/chosenMascot.png',
      fit: BoxFit.contain,
    ),
  ),
),

Positioned(
  left: w * 0.17,
  top: h * 0.183,
  width: w * 0.114,
  height: h * 0.114,
 
    child: Image.asset(
      'assets/livelight.png',
      fit: BoxFit.contain,
    ),

),

Positioned(
  left: w * -0.04,
  top: h * 0.426,
  width: w * 0.14,
  height: h * 0.14,
  child: Opacity(
    opacity: isPowerOn ? 0.8 : 0.0,
    child: Image.asset(
      'assets/light1.png',
      fit: BoxFit.contain,
    ),
  ),
),



Positioned(
  left: w * 0.459,
  bottom: h * 0.115,
  width: w * 0.09,
  height: h * 0.09,
  child: Opacity(
    opacity: isPowerOn ? 0.8 : 0.0,
    child: Image.asset(
      'assets/nose.png',
      fit: BoxFit.contain,
    ),
  ),
),

             Positioned(
  left: w * 0.126,
  top: h * 0.409,
  width: w * 0.19,
  height: h * 0.19,
  child: Opacity(
    opacity: isPowerOn ? 0.8 : 0.0,
    child: Image.asset(
      'assets/light2.png',
      fit: BoxFit.contain,
    ),
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
                  right: w * 0.085,
                  top: h * 0.189,
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
                          height: h * 0.102,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),


// Window maximise / restore button.
Positioned(
  left: w * 0.825,
  top: h * 0.188,
  child: MouseRegion(
    cursor: SystemMouseCursors.click,

    onEnter: (_) {
      setState(() {
        windowIsHovered = true;
      });
    },

    onExit: (_) {
      setState(() {
        windowIsHovered = false;
        windowIsPressed = false;
      });
    },

    child: GestureDetector(
      onTapDown: (_) {
        setState(() {
          windowIsPressed = true;
        });
      },

      onTapUp: (_) {
        setState(() {
          windowIsPressed = false;
        });
      },

      onTapCancel: () {
        setState(() {
          windowIsPressed = false;
        });
      },

      onTap: toggleWindowSize,

      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,

        child: Image.asset(
          windowButtonImage,
          key: ValueKey(windowButtonImage),
          height: h * 0.102,
          fit: BoxFit.contain,
        ),
      ),
    ),
  ),
),



                // Minimise window button.
                Positioned(
                  left: w * 0.778,
                  top: h * 0.192,
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
                  left: w * 0.692,
                  top: h * 0.78,
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

              // ON/OFF power button.
// ON/OFF power button.
Positioned(
  left: w * 0.067,
  bottom: h * 0.077,
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
          onButtonImage,
          key: ValueKey(onButtonImage),
          width: w * 0.058,
          fit: BoxFit.contain,
        ),
      ),
    ),
  ),
),  
// Red LIVE indicator - only visible when broadcaster is live.
Positioned(
  left: w * 0.18,
  top: h * 0.188,
  child: ValueListenableBuilder<bool>(
    valueListenable: streamingService.isBroadcasterLive,
    builder: (context, isLive, child) {
      if (!isLive) {
        return const SizedBox.shrink();
      }

      return Image.asset(
        'assets/live.png',
        height: h * 0.106,
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
