
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:desktop_music_player/services/streaming_service.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:battery_plus/battery_plus.dart';
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
double volume = 0.7;

// Wi-Fi monitoring.
int? _wifiSignal;
bool _wifiConnected = false;
late Timer _wifiRefreshTimer;

late final Battery _battery;

int? _batteryLevel;

late Timer _batteryRefreshTimer;

StreamSubscription<BatteryState>? _batteryStateSubscription;
bool sliderIsHovered = false;
bool sliderIsPressed = false;
  // LiveKit streaming service.
  late final StreamingService streamingService;
late AnimationController mascotController;
late Animation<double> mascotOpacity;
  bool isConnecting = false;
  bool isListening = false;

String _currentTime = '';

late Timer _clockTimer;
  @override
void initState() {
  super.initState();
  // Initialise device clock.

  // Initialise battery monitoring.
_battery = Battery();

// Get initial battery percentage.
_updateBattery();

// Refresh battery percentage every 30 seconds.
_batteryRefreshTimer = Timer.periodic(
  const Duration(seconds: 30),
  (_) => _updateBattery(),
);

// Refresh when charging state changes.
_batteryStateSubscription =
    _battery.onBatteryStateChanged.listen((state) {
  _updateBattery();
});

// Get initial Wi-Fi signal.
_updateWifi();

// Refresh Wi-Fi signal every 5 seconds.
_wifiRefreshTimer = Timer.periodic(
  const Duration(seconds: 5),
  (_) => _updateWifi(),
);
_updateClock();

// Refresh the displayed time every second.
_clockTimer = Timer.periodic(
  const Duration(seconds: 1),
  (_) => _updateClock(),
);

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

Future<void> _updateBattery() async {
  try {
    final level = await _battery.batteryLevel;

    if (!mounted) return;

    if (_batteryLevel != level) {
      setState(() {
        _batteryLevel = level;
      });
    }
  } catch (e) {
   // debugPrint('Battery check failed: $e');
  }
}
Future<void> _updateWifi() async {
  try {
    final result = await Process.run(
      'netsh',
      ['wlan', 'show', 'interfaces'],
    );

    final output = result.stdout.toString();
//debugPrint('WIFI OUTPUT:\n$output');
//debugPrint('WIFI ERROR:\n${result.stderr}');
//debugPrint('WIFI EXIT CODE: ${result.exitCode}');
    final stateMatch = RegExp(
      r'^\s*State\s*:\s*(.+)$',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(output);

    final signalMatch = RegExp(
      r'^\s*Signal\s*:\s*(\d+)%',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(output);

    final connected =
        stateMatch?.group(1)?.trim().toLowerCase() == 'connected';

    final signal = connected
        ? int.tryParse(signalMatch?.group(1) ?? '')
        : null;
//debugPrint('WiFi connected: $connected | Signal: $signal');
    if (!mounted) return;

    if (_wifiConnected != connected || _wifiSignal != signal) {
      setState(() {
        _wifiConnected = connected;
        _wifiSignal = signal;
      });
    }
  } catch (e) {
    //debugPrint('Wi-Fi check failed: $e');
  }
}

void _updateClock() {
  final now = DateTime.now();

  final formattedTime =
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';

  if (formattedTime != _currentTime && mounted) {
    setState(() {
      _currentTime = formattedTime;
    });
  }
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
      //debugPrint('Connection error: $e');

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


void updateVolume(double pointerX, double trackWidth) {
  const grooveStart = 0.205;
  const grooveEnd = 0.96;

  final knobWidth = trackWidth * 0.16;

  final minPosition = trackWidth * grooveStart + knobWidth / 2;
  final maxPosition = trackWidth * grooveEnd - knobWidth / 2;

  final newVolume = ((pointerX - minPosition) /
          (maxPosition - minPosition))
      .clamp(0.0, 1.0);

  setState(() {
    volume = newVolume;
  });
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
  _batteryRefreshTimer.cancel();
  _wifiRefreshTimer.cancel();
_batteryStateSubscription?.cancel();
_clockTimer.cancel();
  unawaited(streamingService.dispose());
  super.dispose();
}

String get sliderButtonImage {
  if (sliderIsPressed) {
    return 'assets/sliderbutpressed.png';
  }

  if (sliderIsHovered) {
    return 'assets/sliderbuthovered.png';
  }

  return 'assets/sliderbut.png';
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
          final songFontSize = h * 0.122;
        final stationFontSize = h * 0.10;
          final playButtonWidth = w * 0.24;
          final minButtonWidth = w * 0.047;

          return DragToResizeArea(
            resizeEdgeSize: 10,
            child: Stack(
              children: [
                // Background: radio artwork.
                Positioned.fill(
  child: DragToMoveArea(
    child: Opacity(
      opacity: 1.0, // 0.0 = invisible, 1.0 = fully opaque
      child: Image.asset(
        'assets/player.png',
        fit: BoxFit.fill,
        width: double.infinity,
        height: double.infinity,
      ),
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

// VOLUME SLIDER.
Positioned(
  right: w * 0.12,
  bottom: h*-0.006,
  width: w * 0.308,
  height: h * 0.308,
  child: Center(
    child: SizedBox(
      width: w * 0.31,
      height: w * 0.31 * (296 / 1462),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          final trackHeight = constraints.maxHeight;

          const grooveStart = 0.205;
          const grooveEnd = 0.96;

          final knobWidth = trackWidth * 0.16;
          final knobHeight = knobWidth * (173 / 235);
final fullFillWidth = trackWidth * (grooveEnd - grooveStart);
final fillHeight = trackHeight * 0.38;
          final minPosition =
              trackWidth * grooveStart + knobWidth / 2;

          final maxPosition =
              trackWidth * grooveEnd - knobWidth / 2;

          final knobCenter = minPosition +
              (maxPosition - minPosition) * volume;

          final fillWidth =
              (knobCenter - trackWidth * grooveStart).clamp(
            0.0,
            trackWidth * (grooveEnd - grooveStart),
          );

          return MouseRegion(
            cursor: SystemMouseCursors.click,
          
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,

              onPanDown: (details) {
                setState(() {
                  sliderIsPressed = true;
                });

                updateVolume(
                  details.localPosition.dx,
                  trackWidth,
                );
              },

              onPanUpdate: (details) {
                updateVolume(
                  details.localPosition.dx,
                  trackWidth,
                );
              },

              onPanEnd: (_) {
                setState(() {
                  sliderIsPressed = false;
                });
              },

              onPanCancel: () {
                setState(() {
                  sliderIsPressed = false;
                });
              },

              child: Stack(
                clipBehavior: Clip.none,
                children: [

                  // Background track.
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.5,
                      child: Image.asset(
                        'assets/volarea.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),

                  // Cyan volume fill.
                  // Cyan volume fill.

  Positioned(
  left: trackWidth * 0.22,  // Adjust horizontal position
  top: trackHeight * 0.245,  
  width: fillWidth,
  height: fillHeight,
  child: ClipRect(
    child: OverflowBox(
      alignment: Alignment.centerLeft,
      minWidth: fullFillWidth,
      maxWidth: fullFillWidth,
      minHeight: fillHeight,
      maxHeight: fillHeight,
      child: Image.asset(
        'assets/cyanfill.png',
        width: fullFillWidth,
        height: fillHeight,
        fit: BoxFit.fill,
      ),
    ),
  ),
),



                  // Draggable slider knob.
                  // SLIDER KNOB.
// SLIDER KNOB.
// SLIDER KNOB.
Positioned(
  left: knobCenter - knobWidth / 2 + trackWidth * 0.00,
  top: (trackHeight - knobHeight) / 2 + trackHeight * -0.052,
  width: knobWidth * 0.98,
  height: knobHeight * 0.98,
  child: MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) {
      setState(() {
        sliderIsHovered = true;
      });
    },
    onExit: (_) {
      setState(() {
        sliderIsHovered = false;
      });
    },
    child: Image.asset(
      sliderButtonImage,
      fit: BoxFit.contain,
    ),
  ),
),
                ],
              ),
            ),
          );
        },
      ),
    ),
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
                // Song title.

Positioned(
  left: w * 0.26,
  top: h * 0.495,
  width: w * 0.41,
  child: ScrollingSongTitle(
    title: 'The Man - Taylor Swift',
    style: TextStyle(
      fontFamily: 'digital',
      color: const Color(0xFF94FFFF),
      fontSize: songFontSize,
      fontStyle: FontStyle.italic,
      shadows: [
        Shadow(
          color: const Color(0xFF00FFFF).withOpacity(0.8),
          blurRadius: 8,
        ),
        Shadow(
          color: const Color(0xFF00FFFF).withOpacity(0.4),
          blurRadius: 16,
        ),
        Shadow(
          color: const Color(0xFF00FFFF).withOpacity(0.2),
          blurRadius: 25,
        ),
      ],
    ),
  ),
),


// Live 32-band equaliser, positioned to the right of the song title.
Positioned(
  left: w * 0.69,
  top: h * 0.49,
  width: w * 0.22,
  height: h * 0.135,
  child: IgnorePointer(
    child: Opacity(
      //opacity: isPowerOn ? 1.0 : 0.0,
      opacity: 1.0,
      child: ValueListenableBuilder<List<double>>(
        valueListenable: streamingService.equaliserBands,
        builder: (context, bands, child) {
          return CustomPaint(
            painter: _EqualiserPainter(bands),
            size: Size.infinite,
          );
        },
      ),
    ),
  ),
),

Positioned(
  left: w * 0.263,
  top: h * 0.362,
  width: w,
  child: Align(
    alignment: Alignment.centerLeft,
    child: Text(
      'SASHA.FM ◕ ‿-｡︻デ┳═ー',
      style: TextStyle(
        color: const Color(0xFF94FFFF),
        fontSize: stationFontSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'dot',
        shadows: [
          Shadow(
            color: const Color(0xFF00FFFF),
            blurRadius: 3,
          ),
        ],
      ),
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

// WI-FI INDICATOR
// WI-FI INDICATOR
Positioned(
  right: w * 0.146,
  top: h * 0.39,
  child: WifiIcon(
    signal: _wifiSignal,
    connected: _wifiConnected,
    size: h * 0.048,
  ),
),
// BATTERY INDICATOR
// BATTERY INDICATOR
Positioned(
  right: w * 0.18,
  top: h * 0.39,
  child: BatteryIcon(
    level: _batteryLevel,
    size: h * 0.05,
  ),
),

// DEVICE CLOCK
Positioned(
  right: w * 0.084,
  top: h * 0.36,
  child: Text(
    _currentTime,
    style: TextStyle(
      fontFamily: 'dot',
      fontSize: h * 0.09,
      color: const Color(0xFF94FFFF),
      
      shadows: [
        Shadow(
          color: const Color(0xFF00FFFF),
          blurRadius: 8,
        ),
        Shadow(
          color: const Color(0xFF00FFFF).withOpacity(0.4),
          blurRadius: 16,
        ),
      ],
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
                  right: w * 0.675,
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
                       // debugPrint('EQUALISER BUTTON PRESSED');
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


class BatteryIcon extends StatelessWidget {
  const BatteryIcon({
    super.key,
    required this.level,
    required this.size,
  });

  final int? level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * (38 / 24),
      height: size,
      child: CustomPaint(
        painter: _BatteryPainter(level),
      ),
    );
  }
}
class WifiIcon extends StatelessWidget {
  final int? signal;
  final bool connected;
  final double size;

  const WifiIcon({
    super.key,
    required this.signal,
    required this.connected,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.5,
      height: size,
      child: CustomPaint(
        painter: _WifiPainter(
          signal: signal,
          connected: connected,
        ),
      ),
    );
  }
}

class _WifiPainter extends CustomPainter {
  final int? signal;
  final bool connected;

  _WifiPainter({
    required this.signal,
    required this.connected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    canvas.save();
    canvas.scale(size.width / 38, size.height / 30);

    const cyan = Color(0xFF94FFFF);
    const inactive = Color(0xFF35434A);

    final strength = connected ? (signal ?? 0) : 0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final paths = [
      Path()
        ..moveTo(3, 9)
        ..quadraticBezierTo(19, -4, 35, 9),

      Path()
        ..moveTo(9, 16)
        ..quadraticBezierTo(19, 7, 29, 16),

      Path()
        ..moveTo(15, 23)
        ..quadraticBezierTo(19, 19, 23, 23),
    ];

    // Outer, middle and inner arcs.
    final thresholds = [70, 35, 1];

    for (int i = 0; i < paths.length; i++) {
      final active = connected && strength >= thresholds[i];

      paint
        ..color = active ? cyan : inactive
        ..maskFilter = active
            ? const MaskFilter.blur(BlurStyle.normal, 3)
            : null;

      canvas.drawPath(paths[i], paint);

      // Crisp foreground line.
      paint
        ..maskFilter = null
        ..color = active ? cyan : inactive;

      canvas.drawPath(paths[i], paint);
    }

    // Signal dot.
    final dotPaint = Paint()
      ..color = connected ? cyan : inactive
      ..maskFilter = connected
          ? const MaskFilter.blur(BlurStyle.normal, 3)
          : null;

    canvas.drawCircle(
      const Offset(19, 27),
      2.2,
      dotPaint,
    );

    dotPaint.maskFilter = null;

    canvas.drawCircle(
      const Offset(19, 27),
      2.2,
      dotPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WifiPainter oldDelegate) {
    return oldDelegate.signal != signal ||
        oldDelegate.connected != connected;
  }
}
class _BatteryPainter extends CustomPainter {
  _BatteryPainter(this.level);

  final int? level;

  @override
  void paint(Canvas canvas, Size size) {
  if (size.width <= 0 || size.height <= 0) return;

  canvas.save();

  // Scale the original 38 × 24 design to the widget dimensions.
  canvas.scale(size.width / 38, size.height / 24);

  const cyan = Color(0xFF94FFFF);

    final outlinePaint = Paint()
      ..color = cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        2.0,
      );

    final crispOutline = Paint()
      ..color = cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final glowPaint = Paint()
      ..color = cyan
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        3.0,
      );

    final fillPaint = Paint()
      ..color = const Color(0xFFBFFFFF)
      ..style = PaintingStyle.fill;

    // Battery outer body.
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1, 3, 29, 18),
      const Radius.circular(3),
    );

    // Battery terminal.
    final terminal = RRect.fromRectAndRadius(
      const Rect.fromLTWH(30, 8, 4, 8),
      const Radius.circular(1),
    );

    canvas.drawRRect(body, outlinePaint);
    canvas.drawRRect(body, crispOutline);

    canvas.drawRRect(terminal, outlinePaint);
    canvas.drawRRect(terminal, crispOutline);

    // Determine how many segments should illuminate.
    final litSegments = level == null
        ? 0
        : (level! / 25).ceil().clamp(0, 4);

    const segmentWidth = 4.5;
    const segmentGap = 1.5;

    // Draw four individual battery segments.
    for (int i = 0; i < 4; i++) {
      if (i >= litSegments) continue;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          4 + i * (segmentWidth + segmentGap),
          7,
          segmentWidth,
          10,
        ),
        const Radius.circular(0.8),
      );

      canvas.drawRRect(rect, glowPaint);
      canvas.drawRRect(rect, fillPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return oldDelegate.level != level;
  }
}

// Draws the 32 frequency levels received from the C++ broadcaster.

class _EqualiserPainter extends CustomPainter {
  _EqualiserPainter(this.bands);

  final List<double> bands;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    const barCount = 18;
    const segmentCount = 7;

    final horizontalGap = size.width * 0.018;
    final barWidth =
        (size.width - horizontalGap * (barCount - 1)) / barCount;

    final segmentHeight = size.height * 0.085;
    final verticalGap = size.height * 0.035;

    final glowPaint = Paint()
      ..color = const Color(0xFF94FFFF)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        2.5,
      );

    final crispPaint = Paint()
      ..color = const Color(0xFFBFFFFF)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < barCount; i++) {

      double level = 0.0;

      // Read incoming audio if available.
      if (bands.isNotEmpty) {
        final start = (i * bands.length / barCount).floor();

        final end = (((i + 1) * bands.length / barCount).ceil())
            .clamp(start + 1, bands.length)
            .toInt();

        double total = 0;

        for (var j = start; j < end; j++) {
          total += bands[j];
        }

        level = (total / (end - start))
            .clamp(0.0, 1.0)
            .toDouble();
      }

      // Always illuminate at least the bottom segment.
      final litSegments = (level * (segmentCount - 1))
              .ceil()
              .clamp(0, segmentCount - 1)
              .toInt() + 1;

      final x = i * (barWidth + horizontalGap);

      // Draw segments from bottom upwards.
      for (var j = 0; j < litSegments; j++) {
        final y = size.height -
            segmentHeight -
            j * (segmentHeight + verticalGap);

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            y,
            barWidth,
            segmentHeight,
          ),
          const Radius.circular(1.2),
        );

        canvas.drawRRect(rect, glowPaint);
        canvas.drawRRect(rect, crispPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EqualiserPainter oldDelegate) {
    return !identical(oldDelegate.bands, bands);
  }
}



class ScrollingSongTitle extends StatefulWidget {
  const ScrollingSongTitle({
    super.key,
    required this.title,
    required this.style,
  });

  final String title;
  final TextStyle style;

  @override
  State<ScrollingSongTitle> createState() =>
      _ScrollingSongTitleState();
}

class _ScrollingSongTitleState extends State<ScrollingSongTitle>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  Animation<double>? _offsetAnimation;

  double _lastCycleDistance = -1;
  String _lastTitle = '';

  static const double gap = 55.0;
  static const double scrollSpeed = 35.0;
  //static const int pauseMilliseconds = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  
void _configureAnimation(double textWidth) {
  final cycleDistance = textWidth + gap;

  if (_lastTitle == widget.title &&
      _lastCycleDistance == cycleDistance &&
      _offsetAnimation != null) {
    return;
  }

  _lastTitle = widget.title;
  _lastCycleDistance = cycleDistance;

  final scrollMilliseconds =
      (cycleDistance / scrollSpeed * 1000).round();

  _controller.duration = Duration(
    milliseconds: scrollMilliseconds,
  );

  _offsetAnimation = Tween<double>(
    begin: 0,
    end: cycleDistance,
  ).animate(_controller);

  _controller.repeat();
}

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {

        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.title,
            style: widget.style,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        );

        textPainter.layout();

      
final textWidth = textPainter.width;
final textHeight = textPainter.height;

// Reserve extra room for italic font overhang and glow.
const edgeSafety = 30.0;

final availableTextWidth =
    (constraints.maxWidth - edgeSafety).clamp(
      0.0,
      constraints.maxWidth,
    );

//debugPrint(
  //'Song width: $textWidth | '
 // 'Available width: ${constraints.maxWidth} | '
 // 'Scroll threshold: $availableTextWidth',
//);

// Only keep stationary when there is plenty of room.
if (textWidth <= availableTextWidth) {
  if (_controller.isAnimating) {
    _controller.stop();
    _controller.value = 0;
  }

  _lastTitle = widget.title;
  _lastCycleDistance = -1;
  _offsetAnimation = null;

  return SizedBox(
    width: constraints.maxWidth,
    height: textHeight,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        widget.title,
        maxLines: 1,
        softWrap: false,
        style: widget.style,
      ),
    ),
  );
}


        _configureAnimation(textWidth);

        final cycleDistance = textWidth + gap;

        return SizedBox(
          width: constraints.maxWidth,
          height: textHeight,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {

                final offset =
    _offsetAnimation?.value ?? 0.0;

                return CustomPaint(
                  size: Size(
                    constraints.maxWidth,
                    textHeight,
                  ),
                  painter: _DualMarqueePainter(
                    textPainter: textPainter,
                    offset: offset,
                    cycleDistance: cycleDistance,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DualMarqueePainter extends CustomPainter {
  _DualMarqueePainter({
    required this.textPainter,
    required this.offset,
    required this.cycleDistance,
  });

  final TextPainter textPainter;
  final double offset;
  final double cycleDistance;

  @override
  void paint(Canvas canvas, Size size) {

    // First copy.
    textPainter.paint(
      canvas,
      Offset(-offset, 0),
    );

    // Second identical copy.
    textPainter.paint(
      canvas,
      Offset(-offset + cycleDistance, 0),
    );
  }

  @override
  bool shouldRepaint(
    covariant _DualMarqueePainter oldDelegate,
  ) {
    return oldDelegate.offset != offset ||
        oldDelegate.cycleDistance != cycleDistance ||
        oldDelegate.textPainter.text != textPainter.text;
  }
}
