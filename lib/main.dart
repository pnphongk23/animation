import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:google_generative_ai/google_generative_ai.dart';


void main() {
  OpenAI.baseUrl = "https://api.aimlapi.com";  // Add this line
  OpenAI.apiKey = "038fd858e35c4421b0e0cd8620ae03c6";
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Animation Preview',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AnimationPreviewPage(),
    );
  }
}

class _AnimationPreviewPageState extends State<AnimationPreviewPage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late AnimationController _animationController;
  Animation<double>? _animation;
  Widget _previewWidget = const SizedBox();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  Future<Map<String, dynamic>> _parseAnimationWithAI(String input) async {
    final model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: 'AIzaSyD6ntjmXYA2Cqpj_2OMDGLHqPSu_vCT1Pc',
    );

    final prompt = '''convert natural language animation descriptions to JSON: 
      type: The type (fade/fadeIn, fadeOut, rotate, scale, slide);
      duration: in milliseconds;
      curve: The animation curve (linear, easeIn, easeOut, easeInOut, bounceOut, elastic);
      properties: Specific properties for each type:
        - fade/fadeIn: beginOpacity (0-1), endOpacity (0-1)
        - fadeOut: automatically sets beginOpacity=1, endOpacity=0
        - scale: beginScale (0+), endScale (0+)
        - slide: beginX (-1 to 1), beginY (-1 to 1), endX (-1 to 1), endY (-1 to 1)
        - rotate: beginAngle (degrees), endAngle (degrees)
      Response in JSON format only, with array of animations.
      Input: $input''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final content = response.text?.replaceAll('```json', '').replaceAll("JSON", "")
                            .replaceAll('```', '')
                            .trim();
      print('Gemini response: $content');
      
      // Directly return a map with an animations key
      return {
        'animations': json.decode(content ?? '[]')
      };
    } catch (e, stackTrace) {
      print('Gemini API Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _generateAnimation(String input) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Reset the preview widget to initial state
      setState(() {
        _previewWidget = Container(
          width: 100,
          height: 100,
          color: Colors.blue,
        );
      });

      final aiResponse = await _parseAnimationWithAI(input);
      final jsonString = json.encode(aiResponse);
      
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonString);
      if (jsonMatch != null) {
        final List<dynamic> animations = json.decode(jsonMatch.group(0)!);
        
        // Calculate total duration
        int totalDuration = animations.fold<int>(0, 
          (sum, anim) => sum + ((anim['duration'] ?? 1000) as num).round());

        // Dispose existing controller
        if (_animationController.isAnimating) {
          _animationController.stop();
        }
        _animationController.dispose();
        
        // Create new controller with total duration
        _animationController = AnimationController(
          duration: Duration(milliseconds: totalDuration),
          vsync: this,
        );

        // Chain animations
        double startTime = 0.0;
        Widget currentWidget = _previewWidget;  // Store the initial widget
        
        for (var animConfig in animations) {
          double endTime = startTime + (animConfig['duration'] ?? 1000) / totalDuration;
          
          // Create interval for this animation
          final interval = Interval(startTime, endTime);
          currentWidget = _createAnimationWidget(  // Store each animation result
            animConfig,
            interval,
            currentWidget,
          );
          
          startTime = endTime;
        }

        setState(() {
          _previewWidget = currentWidget;  // Set final widget with all animations
        });

        _animationController.forward();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Animation error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

// New method to create animation widget without setState
  Widget _createAnimationWidget(Map<String, dynamic> config, Interval interval, Widget child) {
    final curve = _getCurve(config['curve']);
    final curvedInterval = CurvedAnimation(
      parent: _animationController,
      curve: Interval(interval.begin, interval.end, curve: curve),
      reverseCurve: Interval(interval.begin, interval.end, curve: curve),
    );

    Widget _createFadeWidget(Map<String, dynamic> config, Animation<double> curvedInterval, Widget child) {
      final beginOpacity = config['properties']?['beginOpacity'] ?? 0.0;
      final endOpacity = config['properties']?['endOpacity'] ?? 1.0;
      
      final tween = Tween<double>(
        begin: beginOpacity,
        end: endOpacity,
      );

      return FadeTransition(
        opacity: tween.animate(curvedInterval),
        child: child,
      );
    }

    switch (config['type'].toString().toLowerCase()) {
      case 'fade':
      case 'fadein':
        return _createFadeWidget(config, curvedInterval, child);
      case 'fadeout':
        return _createFadeWidget({
          ...config,
          'properties': {
            'beginOpacity': 1.0,
            'endOpacity': 0.1,
          }
        }, curvedInterval, child);
      case 'scale':
        return _createScaleWidget(config, curvedInterval, child);
      case 'slide':
        return _createSlideWidget(config, curvedInterval, child);
      case 'rotate':
        return _createRotateWidget(config, curvedInterval, child);
      default:
        return child;
    }
  }

  Curve _getCurve(String? curveName) {
    switch (curveName?.toLowerCase()) {
      case 'easein':
        return Curves.easeIn;
      case 'easeout':
        return Curves.easeOut;
      case 'easeinout':
        return Curves.easeInOut;
      case 'bounceout':
        return Curves.bounceOut;
      case 'elastic':
        return Curves.elasticIn;
      default:
        return Curves.linear;
    }
  }

  Widget _createScaleWidget(Map<String, dynamic> config, Animation<double> curvedInterval, Widget child) {
    final tween = Tween<double>(
      begin: config['properties']?['beginScale'] ?? 0.0,
      end: config['properties']?['endScale'] ?? 1.0,
    );

    final delay = config['properties']?['delay'] ?? 0;

    return FutureBuilder(
      future: Future.delayed(Duration(milliseconds: delay)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return ScaleTransition(
            scale: tween.animate(curvedInterval),
            child: child,
          );
        } else {
          return Container(); // or any placeholder widget
        }
      },
    );
  }

  Widget _createSlideWidget(Map<String, dynamic> config, Animation<double> curvedInterval, Widget child) {
    final tween = Tween<Offset>(
      begin: Offset(config['properties']?['beginX'] ?? -1.0, config['properties']?['beginY'] ?? 0.0),
      end: Offset(config['properties']?['endX'] ?? 0.0, config['properties']?['endY'] ?? 0.0),
    );

    final delay = config['properties']?['delay'] ?? 0;

    return FutureBuilder(
      future: Future.delayed(Duration(milliseconds: delay)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return SlideTransition(
            position: tween.animate(curvedInterval),
            child: child,
          );
        } else {
          return Container(); // or any placeholder widget
        }
      },
    );
  }

  Widget _createRotateWidget(Map<String, dynamic> config, Animation<double> curvedInterval, Widget child) {
    final tween = Tween<double>(
      begin: (config['properties']?['beginAngle'] ?? 0.0) * 3.14159 / 180,
      end: (config['properties']?['endAngle'] ?? 360.0) * 3.14159 / 180,
    );
    return RotationTransition(
      turns: tween.animate(curvedInterval),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Animation Preview'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Describe your animation (e.g., "fade in and scale up slowly")',
                border: OutlineInputBorder(),
              ),
              onSubmitted: _generateAnimation,
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ...[
                const Text(
                  'Preview:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: _previewWidget,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _animationController.reset();
                    _animationController.forward();
                  },
                  child: const Text('Replay Animation'),
                ),
              ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class AnimationPreviewPage extends StatefulWidget {
  const AnimationPreviewPage({super.key});

  @override
  State<AnimationPreviewPage> createState() => _AnimationPreviewPageState();
}
