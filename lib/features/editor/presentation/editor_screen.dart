import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:ui';

import '../../../core/constants/model_catalog.dart';
import '../../../domain/entities/model_info.dart';
import '../../../core/di/state_providers.dart';
import '../../../core/di/repository_providers.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../core/services/voice_input_service.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../core/services/image_service.dart';
import '../../../data/repositories/saved_data_repository.dart';
import '../../../presentation/widgets/particle_background.dart';
import './image_viewer_screen.dart';
import './code_preview_screen.dart';
import './voice_visualizer.dart';
import './live_chat_screen.dart';
import './widgets/typing_indicator.dart';
import '../../../core/services/wallpaper_service.dart';
import '../../../core/services/notification_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

// ── Main EditorScreen ─────────────────────────────────────────────────────

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isResponding = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  late final FlutterTts _tts;
  String _partialVoiceText = '';

  // Attachment state
  final List<String> _pendingAttachments = [];

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((m) {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  // ── Scroll ──────────────────────────────────────────────────────────────
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ── Attachments ─────────────────────────────────────────────────────────
  Future<void> _pickAttachments() async {
    HapticFeedback.lightImpact();

    // Directly open image picker without restrictions
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _pendingAttachments.addAll(
          result.paths.whereType<String>(),
        );
      });
    }
  }

  String _buildAttachmentContext() {
    if (_pendingAttachments.isEmpty) return '';
    final sb = StringBuffer('\n\n[ATTACHMENTS]');
    for (final path in _pendingAttachments) {
      final file = File(path);
      final ext = path.split('.').last.toLowerCase();
      if (['txt', 'md', 'csv'].contains(ext)) {
        try {
          final text = file.readAsStringSync();
          sb.write(
              '\n\nFile "${file.uri.pathSegments.last}":\n${text.substring(0, text.length.clamp(0, 1500))}');
        } catch (_) {}
      } else if (ext == 'pdf') {
        sb.write(
            '\n\n[PDF attached: ${file.uri.pathSegments.last}] — describe its contents if possible.');
      } else {
        // Image
        sb.write('\n\n[IMAGE attached: ${file.uri.pathSegments.last}]');
      }
    }
    return sb.toString();
  }

  // ── Messaging ────────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if ((text.isEmpty && _pendingAttachments.isEmpty) || _isResponding) return;

    HapticFeedback.mediumImpact();
    final activeModel = ref.read(activeModelProvider);
    final correctionRepo = ref.read(correctionRepositoryProvider);

    if (activeModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Model not active. Please select a model first.')));
      return;
    }

    final attachments = List<String>.from(_pendingAttachments);
    final displayText = text.isEmpty && attachments.isNotEmpty
        ? '📎 ${attachments.length} attachment(s)'
        : text;

    setState(() {
      _messages.add(ChatMessage(
        content: displayText,
        isUser: true,
        timestamp: DateTime.now(),
        attachmentPaths: attachments.isNotEmpty ? attachments : null,
      ));
      _pendingAttachments.clear();
      _isResponding = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      if (activeModel.hfTaskId == 'text-to-image') {
        setState(() {
          _messages.add(ChatMessage(
              content: 'Generating image...',
              isUser: false,
              timestamp: DateTime.now()));
        });
        final imageBytes =
            await correctionRepo.generateImage(activeModel.id, text);
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'gen_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(imageBytes);

        if (mounted) {
          setState(() {
            _messages.last = ChatMessage(
              content: 'Generated Image',
              isUser: false,
              timestamp: DateTime.now(),
              isImage: true,
              imageUrl: file.path,
            );
            _isResponding = false;
          });
          _scrollToBottom();
        }
      } else {
        String aiResponse = '';
        setState(() {
          _messages.add(ChatMessage(
              content: '', isUser: false, timestamp: DateTime.now()));
        });

        final rawMessage = text + _buildAttachmentContext();
        final history = _buildHistory();

        final imagePaths = attachments.where((p) {
          final ext = p.split('.').last.toLowerCase();
          return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);
        }).toList();

        await for (final token in correctionRepo
            .correctTextStream(rawMessage, history, imagePaths: imagePaths)) {
          if (mounted) {
            setState(() {
              aiResponse += token;
              _messages.last = ChatMessage(
                  content: aiResponse,
                  isUser: false,
                  timestamp: DateTime.now());
            });
            _scrollToBottom();
          }
        }
        final historyRepo = ref.read(historyRepositoryProvider);
        await historyRepo.saveHistory(
            originalText: text,
            correctedText: aiResponse,
            explanation: [],
            style: 'Chat');
        await _sendCompletionNotification(aiResponse);
        if (mounted) setState(() => _isResponding = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResponding = false);
        final errorMessage = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Hugging Face API: ', '');
        if (_messages.isNotEmpty) {
          _messages.last = ChatMessage(
              content: '⚠️ $errorMessage',
              isUser: false,
              timestamp: DateTime.now());
        }
      }
    }
  }

  // ── Image Actions ────────────────────────────────────────────────────────
  Future<void> _setWallpaper(String path) async {
    HapticFeedback.mediumImpact();
    final success = await WallpaperService.setWallpaper(path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Wallpaper set successfully!'
            : 'Failed to set wallpaper.'),
        backgroundColor: success ? EdgeTheme.successGreen : EdgeTheme.errorRed,
      ));
    }
  }

  Future<void> _showImageActions(String path, int index) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
            color: EdgeTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionTile(FontAwesomeIcons.image, 'Set as Wallpaper',
                () => _setWallpaper(path)),
            _buildActionTile(FontAwesomeIcons.download, 'Save to Gallery',
                () => _saveToGallery(path)),
            _buildActionTile(FontAwesomeIcons.floppyDisk, 'Save to Creations',
                () => _saveAsCreation(path, index)),
            _buildActionTile(FontAwesomeIcons.shareNodes, 'Share Image',
                () => Share.shareXFiles([XFile(path)])),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(FaIconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: FaIcon(icon, color: EdgeTheme.lavender, size: 20),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildImageToolbox(String path, int index) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: EdgeTheme.surfaceColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolButton(FontAwesomeIcons.image, () => _setWallpaper(path),
              'Set Wallpaper'),
          _buildToolDivider(),
          _buildToolButton(
              FontAwesomeIcons.download, () => _saveToGallery(path), 'Export'),
          _buildToolDivider(),
          _buildToolButton(FontAwesomeIcons.floppyDisk,
              () => _saveAsCreation(path, index), 'Save to Creations'),
          _buildToolDivider(),
          _buildToolButton(FontAwesomeIcons.shareNodes,
              () => Share.shareXFiles([XFile(path)]), 'Share'),
        ],
      ),
    );
  }

  Widget _buildToolButton(FaIconData icon, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: FaIcon(icon,
              color: EdgeTheme.lavender.withValues(alpha: 0.9), size: 15),
        ),
      ),
    );
  }

  Widget _buildToolDivider() => Container(
      height: 16,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white10);

  Future<void> _saveAsCreation(String path, int index) async {
    try {
      final repository = ref.read(savedDataRepositoryProvider);
      final prompt = index < _messages.length ? _messages[index].content : '';
      await repository.saveCreation(
        sourcePath: path,
        title: 'Created on ${DateTime.now().toString().split('.')[0]}',
        prompt: prompt.length > 50 ? '${prompt.substring(0, 47)}...' : prompt,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Saved to your Creations!'),
            backgroundColor: EdgeTheme.successGreen));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: EdgeTheme.errorRed));
    }
  }

  Future<void> _saveToGallery(String path) async {
    try {
      await ImageService.saveToGallery(path);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image saved to gallery')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _saveAsArtifact(String code, String? language) async {
    try {
      final repository = ref.read(savedDataRepositoryProvider);
      await repository.saveArtifact(
          code: code,
          title: 'Snippet from ${DateTime.now().toString().split('.')[0]}',
          language: language ?? 'text');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Saved to your Artifacts!'),
            backgroundColor: EdgeTheme.successGreen));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: EdgeTheme.errorRed));
    }
  }

  Future<void> _sendCompletionNotification(String content) async {
    try {
      final settings = ref.read(settingsProvider);
      if (!settings.responseSummaryEnabled) return;
      String summary = content.trim();
      if (summary.length > 50) summary = '${summary.substring(0, 47)}...';
      await NotificationService.showResponseNotification(summary: summary);
    } catch (e) {
      debugPrint('Notification Error: $e');
    }
  }

  Future<void> _speakText(String text) async {
    if (mounted) setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  void _stopSpeaking() {
    _tts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  String _buildHistory() {
    final recentMessages = _messages.length > 8
        ? _messages.sublist(_messages.length - 8)
        : _messages;
    if (recentMessages.isEmpty) return '';
    return recentMessages
        .map((m) => '${m.isUser ? "User" : "Assistant"}: ${m.content}')
        .join('\n\n');
  }

  void _toggleVoiceInput() async {
    if (_isListening) {
      await VoiceInputService.stopListening();
      setState(() {
        _isListening = false;
        if (_partialVoiceText.isNotEmpty) {
          _inputController.text = _partialVoiceText;
          _partialVoiceText = '';
        }
      });
    } else {
      final available = await VoiceInputService.initialize();
      if (!available) return;
      setState(() {
        _isListening = true;
        _partialVoiceText = '';
      });
      VoiceInputService.startListening(onResult: (words) {
        if (mounted) setState(() => _partialVoiceText = words);
      });
    }
  }

  void _goLive() {
    Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LiveChatScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final correctionRepo = ref.watch(correctionRepositoryProvider);
    final isModelLoaded = correctionRepo.isModelLoaded();
    final activeModel = ref.watch(activeModelProvider);
    final personality = ref.watch(settingsProvider).personality;

    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      body: Stack(
        children: [
          const ParticleBackground(),
          // Removed FullscreenThinkingVisualizer - using in-bubble indicator only
          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const FaIcon(FontAwesomeIcons.robot,
                                  color: EdgeTheme.lavender, size: 12),
                              const SizedBox(width: 8),
                              Text('BRAINY.AI',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: EdgeTheme.lavender,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                      )),
                              const SizedBox(width: 8),
                              Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                      color: EdgeTheme.textTertiary,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(personality.displayName.toUpperCase(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: EdgeTheme.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      )),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isResponding
                                      ? EdgeTheme.lavender
                                      : (isModelLoaded
                                          ? EdgeTheme.successGreen
                                          : Colors.white24),
                                  shape: BoxShape.circle,
                                  boxShadow: _isResponding
                                      ? EdgeTheme.purpleGlow(EdgeTheme.lavender)
                                      : [],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isResponding
                                    ? 'RESPONDING...'
                                    : (isModelLoaded
                                        ? ((activeModel?.isRemote ?? false)
                                            ? 'CLOUD CORE ACTIVE'
                                            : 'LOCAL CORE ACTIVE')
                                        : 'OFFLINE'),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: EdgeTheme.textTertiary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Go Live button
                      GestureDetector(
                        onTap: _goLive,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF6C47FF), Color(0xFF00BFFF)]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      EdgeTheme.lavender.withValues(alpha: 0.3),
                                  blurRadius: 12),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FaIcon(FontAwesomeIcons.waveSquare,
                                  color: Colors.white, size: 10),
                              SizedBox(width: 6),
                              Text('LIVE',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5)),
                            ],
                          ),
                        ),
                      ),
                      Builder(
                          builder: (context) => GestureDetector(
                                onTap: () =>
                                    Scaffold.of(context).openEndDrawer(),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: EdgeTheme.surfaceColor,
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: Colors.white10)),
                                  child: const FaIcon(
                                      FontAwesomeIcons.barsStaggered,
                                      size: 16,
                                      color: Colors.white),
                                ),
                              )),
                    ],
                  ),
                ),
              ),

              // Messages or empty state
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: EdgeTheme.surfaceColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: EdgeTheme.lavender
                                        .withValues(alpha: 0.3)),
                                boxShadow:
                                    EdgeTheme.purpleGlow(EdgeTheme.lavender),
                              ),
                              child: FaIcon(personality.avatarIcon,
                                  size: 80, color: EdgeTheme.lavender),
                            ),
                            const SizedBox(height: 24),
                            Text('How can I help you?',
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            Text('Tap LIVE for hands-free conversation',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: EdgeTheme.textTertiary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _buildMessageBubble(
                            _messages[index], index, personality, activeModel),
                      ),
              ),

              // Attachment tray
              if (_pendingAttachments.isNotEmpty) _buildAttachmentTray(),

              _buildInputArea(activeModel),
            ],
          ),
          if (_isSpeaking) VoiceVisualizerOverlay(onStop: _stopSpeaking),
        ],
      ),
    );
  }

  Widget _buildAttachmentTray() {
    return Container(
      height: 90,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingAttachments.length,
        itemBuilder: (context, i) {
          final path = _pendingAttachments[i];
          final ext = path.split('.').last.toLowerCase();
          final isImage =
              ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);

          return Container(
            width: 72,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: EdgeTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.2)),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isImage
                      ? Image.file(File(path),
                          width: 72, height: 90, fit: BoxFit.cover)
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FaIcon(_fileIcon(ext),
                                  color: EdgeTheme.lavender, size: 22),
                              const SizedBox(height: 4),
                              Text(ext.toUpperCase(),
                                  style: const TextStyle(
                                      color: EdgeTheme.textTertiary,
                                      fontSize: 9)),
                            ],
                          ),
                        ),
                ),
                Positioned(
                  top: 3,
                  right: 3,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _pendingAttachments.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 10),
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

  FaIconData _fileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return FontAwesomeIcons.filePdf;
      case 'txt':
      case 'md':
        return FontAwesomeIcons.fileLines;
      case 'csv':
        return FontAwesomeIcons.fileExcel;
      case 'docx':
        return FontAwesomeIcons.fileWord;
      default:
        return FontAwesomeIcons.file;
    }
  }

  String _cleanAiResponse(String text) {
    if (text.isEmpty) return text;
    var cleaned = text.replaceAll(
        RegExp(r'<\|channel>thought.*?<channel\|>', dotAll: true), '');
    final unclosedIndex = cleaned.indexOf('<|channel>thought');
    if (unclosedIndex != -1) {
      cleaned = cleaned.substring(0, unclosedIndex);
    }
    cleaned =
        cleaned.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    final unclosedThink = cleaned.indexOf('<think>');
    if (unclosedThink != -1) {
      cleaned = cleaned.substring(0, unclosedThink);
    }
    return cleaned.trimLeft();
  }

  Widget _buildMessageBubble(ChatMessage message, int index,
      dynamic personality, ModelInfo? activeModel) {
    final isLast = index == _messages.length - 1;
    final displayContent =
        message.isUser ? message.content : _cleanAiResponse(message.content);
    final isLlmThinking =
        !message.isUser && displayContent.isEmpty && _isResponding && isLast;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: EdgeTheme.lavender.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: FaIcon(personality.avatarIcon,
                  size: 16, color: EdgeTheme.lavender),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: GlowingBorder(
              isActive: !message.isUser && _isResponding && isLast,
              borderRadius: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(message.isUser ? 24 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 24),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? EdgeTheme.lavender.withValues(alpha: 0.1)
                          : EdgeTheme.surfaceColor.withValues(alpha: 0.8),
                      border: Border.all(
                          color: message.isUser
                              ? EdgeTheme.lavender.withValues(alpha: 0.2)
                              : Colors.white10),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(24),
                        topRight: const Radius.circular(24),
                        bottomLeft: Radius.circular(message.isUser ? 24 : 4),
                        bottomRight: Radius.circular(message.isUser ? 4 : 24),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Attachment preview in bubble
                        if (message.attachmentPaths != null &&
                            message.attachmentPaths!.isNotEmpty)
                          _buildBubbleAttachments(message.attachmentPaths!),
                        if (isLlmThinking)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: TypingIndicator(),
                          )
                        else if (message.isImage && message.imageUrl != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ImageViewerScreen(
                                            imagePath: message.imageUrl!,
                                            tag: 'img_$index'))),
                                onLongPress: () =>
                                    _showImageActions(message.imageUrl!, index),
                                child: Hero(
                                  tag: 'img_$index',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(File(message.imageUrl!),
                                        fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                              _buildImageToolbox(message.imageUrl!, index),
                            ],
                          )
                        else
                          MarkdownBody(
                            data: displayContent,
                            selectable: true,
                            builders: {
                              'code':
                                  CodeElementBuilder(context, _saveAsArtifact)
                            },
                            styleSheet: MarkdownStyleSheet(
                              p: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                      color: EdgeTheme.textPrimary,
                                      height: 1.6),
                              code: const TextStyle(
                                  backgroundColor: Colors.transparent,
                                  color: EdgeTheme.lavender,
                                  fontFamily: 'monospace',
                                  fontSize: 13),
                              codeblockDecoration: const BoxDecoration(
                                  color: Colors.transparent),
                              blockquote: const TextStyle(
                                  color: EdgeTheme.textSecondary,
                                  fontStyle: FontStyle.italic),
                              listBullet:
                                  const TextStyle(color: EdgeTheme.lavender),
                            ),
                          ),
                        if (!message.isUser &&
                            message.content.isNotEmpty &&
                            !_isResponding)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const FaIcon(
                                      FontAwesomeIcons.volumeHigh,
                                      size: 14),
                                  onPressed: () => _speakText(message.content),
                                  style: IconButton.styleFrom(
                                      backgroundColor: Colors.white10,
                                      padding: const EdgeInsets.all(8)),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const FaIcon(FontAwesomeIcons.copy,
                                      size: 14),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: message.content));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Copied!')));
                                  },
                                  style: IconButton.styleFrom(
                                      backgroundColor: Colors.white10,
                                      padding: const EdgeInsets.all(8)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleAttachments(List<String> paths) {
    if (paths.isEmpty) return const SizedBox.shrink();
    final images = paths.where((p) {
      final ext = p.split('.').last.toLowerCase();
      return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);
    }).toList();
    final files = paths.where((p) {
      final ext = p.split('.').last.toLowerCase();
      return !['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: images
                  .map((p) => GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ImageViewerScreen(imagePath: p, tag: p))),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 80,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(p), fit: BoxFit.cover),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ...files.map((p) {
          final name = p.split('/').last;
          final ext = name.split('.').last.toLowerCase();
          return Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(_fileIcon(ext), color: EdgeTheme.lavender, size: 14),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(name,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildInputArea(ModelInfo? activeModel) {
    final hasText = _inputController.text.trim().isNotEmpty;
    final hasAttachments = _pendingAttachments.isNotEmpty;
    final showSendButton = hasText || hasAttachments;

    return Container(
      color: EdgeTheme.primaryBackground,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attachment preview chips above input
            if (hasAttachments) _buildAttachmentChips(),

            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Plus button for attachments (left)
                  GestureDetector(
                    onTap: _pickAttachments,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: EdgeTheme.secondarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.plus,
                          color: EdgeTheme.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Image/Gallery button
                  GestureDetector(
                    onTap: _pickImageFromGallery,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: EdgeTheme.secondarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.image,
                          color: EdgeTheme.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Text input field (center, expands)
                  Expanded(
                    child: Container(
                      height: 44, // ✅ Match button height
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: EdgeTheme.secondarySurface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _inputController,
                        maxLines: 1, // ✅ Keep height consistent
                        expands: false,
                        textAlignVertical: TextAlignVertical
                            .center, // ✅ Center text vertically
                        textInputAction: TextInputAction.newline,
                        onChanged: (val) {
                          setState(() {});
                        },
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.2,
                        ),
                        decoration: InputDecoration(
                          hintText: activeModel?.hfTaskId == 'text-to-image'
                              ? 'Describe image...'
                              : 'Message',
                          hintStyle: TextStyle(
                            color:
                                EdgeTheme.textTertiary.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),

                          // ✅ REMOVE ALL BORDERS (normal + focused)
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,

                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Mic/Send button (right)
                  GestureDetector(
                    onTap: _isResponding
                        ? null
                        : (showSendButton ? _sendMessage : _toggleVoiceInput),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: showSendButton && !_isResponding
                            ? EdgeTheme.lavender
                            : EdgeTheme.secondarySurface,
                        shape: BoxShape.circle,
                        boxShadow: showSendButton && !_isResponding
                            ? [
                                BoxShadow(
                                  color:
                                      EdgeTheme.lavender.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: _isResponding
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : FaIcon(
                                showSendButton
                                    ? FontAwesomeIcons.arrowUp
                                    : FontAwesomeIcons.microphone,
                                color: showSendButton
                                    ? Colors.black
                                    : EdgeTheme.textSecondary,
                                size: 18,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _pendingAttachments.asMap().entries.map((entry) {
            final index = entry.key;
            final path = entry.value;
            final name = path.split('/').last;
            final isImage = _isImageFile(path);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                backgroundColor: EdgeTheme.secondarySurface,
                deleteIconColor: EdgeTheme.textTertiary,
                onDeleted: () {
                  setState(() {
                    _pendingAttachments.removeAt(index);
                  });
                },
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isImage)
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => FaIcon(
                              FontAwesomeIcons.image,
                              size: 12,
                              color: EdgeTheme.lavender,
                            ),
                          ),
                        ),
                      )
                    else
                      FaIcon(
                        _fileIcon(path.split('.').last.toLowerCase()),
                        size: 12,
                        color: EdgeTheme.lavender,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);
  }

  Future<void> _pickImageFromGallery() async {
    HapticFeedback.lightImpact();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        if (file.path != null && !_pendingAttachments.contains(file.path)) {
          setState(() {
            _pendingAttachments.add(file.path!);
          });
        }
      }
    }
  }
}

// ── Code Element Builder ───────────────────────────────────────────────────

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final Function(String, String?) onSave;
  CodeElementBuilder(this.context, this.onSave);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'code' || !element.textContent.contains('\n'))
      return null;
    final String code = element.textContent;
    final String? language =
        element.attributes['class']?.replaceFirst('language-', '');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text((language ?? 'code').toUpperCase(),
                    style: const TextStyle(
                        color: EdgeTheme.lavender,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      icon: const FaIcon(FontAwesomeIcons.copy,
                          size: 11, color: EdgeTheme.textTertiary),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: code)),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6)),
                  IconButton(
                      icon: const FaIcon(FontAwesomeIcons.floppyDisk,
                          size: 11, color: EdgeTheme.lavender),
                      onPressed: () => onSave(code, language),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6)),
                  if (language == 'html' || language == 'javascript')
                    IconButton(
                        icon: const FaIcon(FontAwesomeIcons.play,
                            size: 10, color: EdgeTheme.successGreen),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CodePreviewScreen(
                                    code: code, language: language ?? 'text'))),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6)),
                ]),
              ],
            ),
          ),
          Padding(
              padding: const EdgeInsets.all(14),
              child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(code,
                      style: const TextStyle(
                          color: EdgeTheme.textPrimary,
                          fontFamily: 'monospace',
                          fontSize: 12)))),
        ],
      ),
    );
  }
}

// ── Data Models ────────────────────────────────────────────────────────────

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isImage;
  final String? imageUrl;
  final List<String>? attachmentPaths;

  const ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isImage = false,
    this.imageUrl,
    this.attachmentPaths,
  });
}

class GlowingBorder extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final bool isActive;
  const GlowingBorder(
      {super.key,
      required this.child,
      this.borderRadius = 0,
      this.isActive = false});

  @override
  Widget build(BuildContext context) {
    if (!isActive) return child;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
              color: EdgeTheme.lavender.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2)
        ],
      ),
      child: child,
    );
  }
}
