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
      type: The type (fade, rotate,...); 
      duration: in milliseconds; 
      curve: The animation curve (linear, easeIn, etc.);
      properties: Specific properties for the animation. 
      Response in JSON format only, with array of animations.
      Input: $input''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final content = response.text;
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
      // First parse the input with AI
      final aiResponse = await _parseAnimationWithAI(input);
      
      // Convert the AI response to a string for JSON parsing
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
        for (var animConfig in animations) {
          double endTime = startTime + (animConfig['duration'] ?? 1000) / totalDuration;
          
          // Create interval for this animation
          final interval = Interval(startTime, endTime);
          _createAnimation(
            Map<String, dynamic>.from(animConfig), 
            interval
          );
          
          startTime = endTime;
        }

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

  void _createAnimation(Map<String, dynamic> config, Interval interval) {
    final curve = _getCurve(config['curve']);
    final curvedInterval = CurvedAnimation(
      parent: _animationController,
      curve: Interval(interval.begin, interval.end, curve: curve),
    );

    switch (config['type'].toString().toLowerCase()) {
      case 'fade':
      case 'fadein':
        _createFadeAnimation(config, curvedInterval);
        break;
      case 'fadeout':
        _createFadeAnimation({
          ...config,
          'properties': {
            'beginOpacity': 1.0,
            'endOpacity': 0.0,
          }
        }, curvedInterval);
        break;
      case 'scale':
        _createScaleAnimation(config, curvedInterval);
        break;
      case 'slide':
        _createSlideAnimation(config, curvedInterval);
        break;
      case 'rotate':
        _createRotateAnimation(config, curvedInterval);
        break;
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

  void _createFadeAnimation(Map<String, dynamic> config, Animation<double> curvedInterval) {
    final tween = Tween<double>(
      begin: config['properties']?['beginOpacity'] ?? 0.0,
      end: config['properties']?['endOpacity'] ?? 1.0,
    );
    setState(() {
      _previewWidget = FadeTransition(
        opacity: tween.animate(curvedInterval),
        child: _previewWidget.runtimeType == SizedBox ? Container(
          width: 100,
          height: 100,
          color: Colors.blue,
        ) : _previewWidget,
      );
    });
  }

  void _createScaleAnimation(Map<String, dynamic> config, Animation<double> curvedInterval) {
    final tween = Tween<double>(
      begin: config['properties']?['beginScale'] ?? 0.0,
      end: config['properties']?['endScale'] ?? 1.0,
    );
    setState(() {
      _previewWidget = ScaleTransition(
        scale: tween.animate(curvedInterval),
        child: _previewWidget.runtimeType == SizedBox ? Container(
          width: 100,
          height: 100,
          color: Colors.blue,
        ) : _previewWidget,
      );
    });
  }

  void _createSlideAnimation(Map<String, dynamic> config, Animation<double> curvedInterval) {
    final tween = Tween<Offset>(
      begin: Offset(config['properties']?['beginX'] ?? -1.0, config['properties']?['beginY'] ?? 0.0),
      end: Offset(config['properties']?['endX'] ?? 0.0, config['properties']?['endY'] ?? 0.0),
    );
    setState(() {
      _previewWidget = SlideTransition(
        position: tween.animate(curvedInterval),
        child: _previewWidget.runtimeType == SizedBox ? Container(
          width: 100,
          height: 100,
          color: Colors.blue,
        ) : _previewWidget,
      );
    });
  }

  void _createRotateAnimation(Map<String, dynamic> config, Animation<double> curvedInterval) {
    final tween = Tween<double>(
      begin: (config['properties']?['beginAngle'] ?? 0.0) * 3.14159 / 180,
      end: (config['properties']?['endAngle'] ?? 360.0) * 3.14159 / 180,
    );
    setState(() {
      _previewWidget = RotationTransition(
        turns: tween.animate(curvedInterval),
        child: _previewWidget.runtimeType == SizedBox ? Container(
          width: 100,
          height: 100,
          color: Colors.blue,
        ) : _previewWidget,
      );
    });
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
