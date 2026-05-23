import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/di/state_providers.dart';
import '../../../core/di/repository_providers.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../core/services/voice_input_service.dart';
import './widgets/aura_visualizer.dart';

/// Gemini Live–style immersive voice chat screen.
class LiveChatScreen extends ConsumerStatefulWidget {
  const LiveChatScreen({super.key});

  @override
  ConsumerState<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends ConsumerState<LiveChatScreen>
    with TickerProviderStateMixin {
  //── State ──────────────────────────────────────────────────────────────────
  AuraState _auraState = AuraState.idle;
  final double _amplitude = 0.0;
  bool _isMuted = false;
  bool _sessionActive = true;
  String _transcript = '';
  String _aiResponse = '';
  final List<_LiveTurn> _turns = [];

  late final FlutterTts _tts;
  late AnimationController _bgController;

  //── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _tts = FlutterTts();
    _tts.setStartHandler(() => setState(() {
          _auraState = AuraState.speaking;
        }));
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _auraState = AuraState.idle);
        // After AI speaks, immediately start listening again
        _startListening();
      }
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _auraState = AuraState.idle);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _auraState = AuraState.idle);
    });

    // Kick off first listen
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  @override
  void dispose() {
    _bgController.dispose();
    _tts.stop();
    VoiceInputService.cancel();
    super.dispose();
  }

  //── Core Logic ──────────────────────────────────────────────────────────────
  Future<void> _startListening() async {
    if (!_sessionActive || _isMuted) return;

    final available = await VoiceInputService.initialize();
    if (!available || !mounted) return;

    setState(() {
      _auraState = AuraState.listening;
      _transcript = '';
    });

    await VoiceInputService.startLiveListening(
      onPartialResult: (words) {
        if (mounted) setState(() => _transcript = words);
      },
      onSilence: () {
        if (_transcript.isNotEmpty && mounted) {
          _sendLiveMessage(_transcript);
        }
      },
    );
  }

  Future<void> _sendLiveMessage(String text) async {
    await VoiceInputService.stopListening();
    if (!mounted) return;

    setState(() {
      _turns.add(_LiveTurn(text: text, isUser: true));
      _transcript = '';
      _auraState = AuraState.thinking;
      _aiResponse = '';
    });

  String _cleanAiResponse(String text) {
    if (text.isEmpty) return text;
    var cleaned = text.replaceAll(RegExp(r'<\|channel>thought.*?<channel\|>', dotAll: true), '');
    final unclosedIndex = cleaned.indexOf('<|channel>thought');
    if (unclosedIndex != -1) {
      cleaned = cleaned.substring(0, unclosedIndex);
    }
    cleaned = cleaned.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    final unclosedThink = cleaned.indexOf('<think>');
    if (unclosedThink != -1) {
      cleaned = cleaned.substring(0, unclosedThink);
    }
    return cleaned.trimLeft();
  }

    try {
      final correctionRepo = ref.read(correctionRepositoryProvider);
      final settings = ref.read(settingsProvider);
      final personality = settings.personality;
      String systemPrompt = personality.buildSystemPrompt();
      if (settings.disableDeepReasoning) {
        systemPrompt += '\nIMPORTANT INSTRUCTION: Do NOT use any internal reasoning, thinking, or <|channel>thought|> blocks. You must provide the final answer directly, concisely, and immediately.';
      }
      final history = _turns
          .map((t) => '${t.isUser ? "User" : "AI"}: ${t.text}')
          .join('\n');
      final prompt = 'System: $systemPrompt\n\n$history\n\nAI:';

      String response = '';
      await for (final token in correctionRepo.correctTextStream(prompt, '')) {
        if (!mounted) break;
        response += token;
        setState(() => _aiResponse = _cleanAiResponse(response));
      }

      final cleanedFinalResponse = _cleanAiResponse(response);

      if (!mounted) return;
      setState(() {
        _turns.add(_LiveTurn(text: cleanedFinalResponse, isUser: false));
        _aiResponse = '';
      });

      // Speak the response
      if (settings.aiVoiceEnabled && cleanedFinalResponse.isNotEmpty) {
        await _tts.setPitch(settings.aiVoicePitch);
        await _tts.setSpeechRate(settings.aiVoiceSpeed);
        await _tts.speak(cleanedFinalResponse);
      } else {
        // Skip speaking, immediately return to listening
        setState(() => _auraState = AuraState.idle);
        _startListening();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _auraState = AuraState.idle;
        _turns.add(_LiveTurn(text: '⚠️ ${e.toString()}', isUser: false));
      });
      _startListening();
    }
  }

  void _toggleMute() {
    HapticFeedback.mediumImpact();
    setState(() => _isMuted = !_isMuted);
    if (_isMuted) {
      VoiceInputService.cancel();
      setState(() => _auraState = AuraState.idle);
    } else {
      _startListening();
    }
  }

  void _interruptAI() {
    _tts.stop();
    setState(() => _auraState = AuraState.idle);
    _startListening();
  }

  void _endSession() {
    _tts.stop();
    VoiceInputService.cancel();
    setState(() => _sessionActive = false);
    Navigator.pop(context);
  }

  //── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          final t = _bgController.value;
          return Stack(
            children: [
              // Animated gradient background
              Positioned.fill(
                child: CustomPaint(
                  painter: _LiveBgPainter(t: t, auraState: _auraState),
                ),
              ),
              // Frosted glass overlay
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.65),
                  ),
                ),
              ),
              // Removed FullscreenThinkingVisualizer - using AuraVisualizer only
              // Main content
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildCenterArea(size)),
                    _buildTranscriptArea(),
                    _buildBottomControls(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final stateLabel = switch (_auraState) {
      AuraState.idle => 'SYSTEM READY',
      AuraState.listening => 'LISTENING...',
      AuraState.thinking => 'DEEP THINKING...',
      AuraState.speaking => 'SYSTEM RESPONDING',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.robot, color: EdgeTheme.lavender, size: 12),
                    const SizedBox(width: 8),
                    const Text('BRAINY.AI • LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 4,
                        )),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(stateLabel,
                          style: TextStyle(
                            color: _auraState == AuraState.listening ? const Color(0xFF00E5FF) : (_auraState == AuraState.speaking ? const Color(0xFF69FF47) : Colors.white60),
                            fontSize: 8,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                          )),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _endSession,
            icon: const FaIcon(FontAwesomeIcons.xmark, color: Colors.white54, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterArea(Size size) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // The Aura Visualizer
        GestureDetector(
          onTap: _auraState == AuraState.speaking ? _interruptAI : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Always show AuraVisualizer - it handles all states internally
              AuraVisualizer(
                state: _auraState,
                amplitude: _amplitude,
              ),
              if (_auraState == AuraState.speaking)
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(FontAwesomeIcons.stop,
                        color: Colors.white, size: 18),
                    SizedBox(height: 6),
                    Text('TAP TO INTERRUPT',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // AI streaming response preview
        if (_aiResponse.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _aiResponse,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTranscriptArea() {
    final hasContent = _transcript.isNotEmpty || _turns.isNotEmpty;
    if (!hasContent) return const SizedBox(height: 80);

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        reverse: true,
        child: Column(
          children: [
            ..._turns.takeLast(4).map((turn) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${turn.isUser ? "You" : "AI"}: ${turn.text}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          turn.isUser ? Colors.white60 : EdgeTheme.lavender.withValues(alpha: 0.8),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                )),
            if (_transcript.isNotEmpty)
              Text(
                _transcript,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 32, 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ControlIcon(
                  icon: _isMuted ? FontAwesomeIcons.microphoneSlash : FontAwesomeIcons.microphone,
                  color: _isMuted ? EdgeTheme.errorRed : Colors.white70,
                  onTap: _toggleMute,
                  isActive: !_isMuted,
                ),
                // Center action - visually distinct
                GestureDetector(
                  onTap: _auraState == AuraState.speaking ? _interruptAI : null,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: _auraState == AuraState.speaking ? EdgeTheme.lavender : Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      boxShadow: _auraState == AuraState.speaking ? EdgeTheme.purpleGlow(EdgeTheme.lavender) : [],
                    ),
                    child: Center(
                      child: FaIcon(
                        _auraState == AuraState.speaking ? FontAwesomeIcons.stop : FontAwesomeIcons.bolt,
                        color: _auraState == AuraState.speaking ? Colors.black : Colors.white38,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                _ControlIcon(
                  icon: FontAwesomeIcons.chevronRight,
                  color: Colors.white70,
                  onTap: _auraState == AuraState.speaking ? _interruptAI : null,
                  isActive: _auraState == AuraState.speaking,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper Widgets ──────────────────────────────────────────────────────────

class _ControlIcon extends StatelessWidget {
  final FaIconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isActive;

  const _ControlIcon({required this.icon, required this.color, this.onTap, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      icon: FaIcon(icon, color: isActive ? color : color.withValues(alpha: 0.3), size: 18),
      padding: const EdgeInsets.all(16),
      style: IconButton.styleFrom(
        backgroundColor: isActive ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
      ),
    );
  }
}

// ── Background Painter ──────────────────────────────────────────────────────

class _LiveBgPainter extends CustomPainter {
  final double t;
  final AuraState auraState;

  _LiveBgPainter({required this.t, required this.auraState});

  @override
  void paint(Canvas canvas, Size size) {
    // Determine color palette based on state
    final Color primary;
    final Color secondary;
    final Color highlight;

    switch (auraState) {
      case AuraState.listening:
        primary = const Color(0xFF001A2E);
        secondary = const Color(0xFF00274D);
        highlight = const Color(0xFF00E5FF).withValues(alpha: 0.15);
        break;
      case AuraState.thinking:
        primary = const Color(0xFF1A0033);
        secondary = const Color(0xFF2D0066);
        highlight = const Color(0xFF9D4EDD).withValues(alpha: 0.15);
        break;
      case AuraState.speaking:
        primary = const Color(0xFF001A0D);
        secondary = const Color(0xFF002B1A);
        highlight = const Color(0xFF69FF47).withValues(alpha: 0.15);
        break;
      case AuraState.idle:
        primary = const Color(0xFF0A0A14);
        secondary = const Color(0xFF14141F);
        highlight = const Color(0xFFFFFFFF).withValues(alpha: 0.05);
        break;
    }

    // 1. Base Gradient
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, secondary],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // 3. Ambient Particles (Pseudo-particles via small circles)
    final rand = math.Random(42);
    for (int i = 0; i < 15; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final offset = Offset(x, (y + t * size.height) % size.height);
      final pSize = rand.nextDouble() * 2 + 1;
      canvas.drawCircle(
        offset, 
        pSize, 
        Paint()..color = highlight.withValues(alpha: rand.nextDouble() * 0.2)
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveBgPainter old) =>
      old.t != t || old.auraState != auraState;
}

// ── Data Models ──────────────────────────────────────────────────────────────

class _LiveTurn {
  final String text;
  final bool isUser;
  _LiveTurn({required this.text, required this.isUser});
}

extension ListTakeLast<T> on List<T> {
  List<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}
