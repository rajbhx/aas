import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/model_catalog.dart';
import '../../../core/di/state_providers.dart';
import '../../../core/di/repository_providers.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../data/datasources/download_manager.dart';
import '../../../data/datasources/external_model_storage.dart';
import '../../../domain/entities/model_info.dart';


/// Model Hub screen - browse and download models
class ModelHubScreen extends ConsumerStatefulWidget {
  const ModelHubScreen({super.key});

  @override
  ConsumerState<ModelHubScreen> createState() => _ModelHubScreenState();
}

class _ModelHubScreenState extends ConsumerState<ModelHubScreen> {
  late DownloadManager _downloadManager;
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};
  List<ModelInfo> _downloadedModels = [];
  String? _selectedCategory;

  // HF Search State
  bool _isCloudMode = false;
  bool _isSearchingHF = false;
  final TextEditingController _searchController = TextEditingController();
  List<ModelInfo> _hfResults = [];

  @override
  void initState() {
    super.initState();
    _downloadManager = DownloadManager(ref.read(dioProvider));
    _loadDownloadedModels();
  }

  @override
  void dispose() {
    _downloadManager.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchHF() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearchingHF = true;
      _isCloudMode = true;
    });

    try {
      final hfService = ref.read(hfServiceProvider);
      final results = await hfService.searchModels(query: query);
      if (mounted) {
        setState(() {
          _hfResults = results;
          _isSearchingHF = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingHF = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  void _selectRemoteModel(ModelInfo model) {
    ref.read(activeModelProvider.notifier).state = model;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Remote core ${model.name} activated.'),
        backgroundColor: EdgeTheme.lavender,
      ),
    );
  }

  Future<void> _loadDownloadedModels() async {
    await ExternalModelStorageService.initialize();
    final files = await ExternalModelStorageService.getModelFiles();
    
    if (mounted) {
      setState(() {
        _downloadedModels = files.map((file) {
          final filename = file.uri.pathSegments.last;
          return ModelInfo(
            id: filename.split('.').first.toLowerCase().replaceAll(' ', '_'),
            name: filename,
            description: 'Downloaded model',
            filename: filename,
            sizeBytes: file.lengthSync(),
            category: ModelCategories.text,
            recommendedRamGB: 0,
            isDownloaded: true,
          );
        }).toList();
      });
    }
  }

  bool _isModelDownloaded(String filename) {
    return _downloadedModels.any((m) => m.filename == filename);
  }

  Future<void> _downloadModel(ModelInfo model) async {
    if (_isDownloading[model.id] == true) return;
    if (model.downloadUrl == null) return;

    setState(() => _isDownloading[model.id] = true);

    try {
      await ExternalModelStorageService.initialize();
      final modelsDir = ExternalModelStorageService.modelsDirectory;
      if (modelsDir == null) throw Exception('Storage not initialized');

      final destPath = '${modelsDir.path}/${model.filename}';

      await _downloadManager.download(
        modelId: model.id,
        url: model.downloadUrl!,
        destinationPath: destPath,
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress[model.id] = progress);
        },
        onComplete: () async {
          if (mounted) {
            setState(() {
              _isDownloading[model.id] = false;
              _downloadProgress.remove(model.id);
            });
            await _loadDownloadedModels();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${model.name} downloaded successfully.'),
                  backgroundColor: EdgeTheme.successGreen,
                ),
              );
            }
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isDownloading[model.id] = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download failed: $error'),
                backgroundColor: EdgeTheme.errorRed,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading[model.id] = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _pauseDownload(String modelId) async {
    _downloadManager.pauseDownload(modelId);
    setState(() => _isDownloading[modelId] = false);
  }

  @override
  Widget build(BuildContext context) {
    final allModels = AvailableModels.getAll();
    final categories = AvailableModels.getCategories();
    
    final displayModels = _isCloudMode 
        ? _hfResults 
        : (_selectedCategory == null
            ? allModels
            : AvailableModels.getByCategory(_selectedCategory!));

    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Node Hub'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.clockRotateLeft, size: 18),
            onPressed: () => context.go('/history'),
          ),
          // Profile Avatar (Cloud Hub)
          Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(hfProfileProvider);
              return profileAsync.when(
                data: (profile) {
                  if (profile == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => context.push('/settings'),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.3)),
                        ),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: EdgeTheme.surfaceColor,
                          backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                          child: profile.avatarUrl == null 
                              ? const FaIcon(FontAwesomeIcons.user, size: 8, color: EdgeTheme.lavender)
                              : null,
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const FaIcon(FontAwesomeIcons.barsStaggered, size: 18),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: EdgeTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _isCloudMode ? 'Search Hugging Face Hub...' : 'Search local catalog...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                        border: InputBorder.none,
                        icon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 14, color: EdgeTheme.textTertiary),
                      ),
                      onSubmitted: (_) {
                        if (_isCloudMode) _searchHF();
                        // Local search could be added here if needed
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: EdgeTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      _buildModeIcon(
                        icon: FontAwesomeIcons.server,
                        isSelected: !_isCloudMode,
                        onTap: () => setState(() => _isCloudMode = false),
                      ),
                      _buildModeIcon(
                        icon: FontAwesomeIcons.cloud,
                        isSelected: _isCloudMode,
                        onTap: () => setState(() => _isCloudMode = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Category Filter
          if (!_isCloudMode)
            Container(
              height: 60,
              margin: const EdgeInsets.only(top: 12),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryChip(
                    label: 'All Cores',
                    icon: FontAwesomeIcons.layerGroup,
                    isSelected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                  ...categories.map((cat) {
                    final tempModel = ModelInfo(
                      id: '', name: '', description: '', filename: '',
                      sizeBytes: 0, category: cat, recommendedRamGB: 0,
                    );
                    return _buildCategoryChip(
                      label: cat.split(' & ').first,
                      icon: tempModel.categoryIcon,
                      isSelected: _selectedCategory == cat,
                      onTap: () => setState(() => _selectedCategory = cat),
                    );
                  }),
                ],
              ),
            ),

          // Count Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Text(
                  _isCloudMode 
                      ? '${_hfResults.length} CLOUD NODES FOUND'
                      : '${displayModels.length} AVAILABLE NODES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: EdgeTheme.textTertiary,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                if (_isSearchingHF)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: EdgeTheme.lavender),
                  )
                else if (!_isCloudMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: EdgeTheme.successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_downloadedModels.length} SYNCED',
                      style: const TextStyle(color: EdgeTheme.successGreen, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          // Models List
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final profileAsync = ref.watch(hfProfileProvider);
                
                return profileAsync.when(
                  data: (profile) {
                    if (displayModels.isEmpty && _isCloudMode && !_isSearchingHF) {
                      return _buildEmptyCloudState();
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: displayModels.length,
                      itemBuilder: (context, index) {
                        final model = displayModels[index];
                        final isDownloaded = _isModelDownloaded(model.filename);
                        final progress = _downloadProgress[model.id] ?? 0.0;
                        final downloading = _isDownloading[model.id] ?? false;

                        return _buildModelCard(model, isDownloaded, downloading, progress);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: EdgeTheme.lavender)),
                  error: (e, _) => const SizedBox.shrink(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeIcon({required FaIconData icon, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? EdgeTheme.lavender.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: FaIcon(icon, size: 14, color: isSelected ? EdgeTheme.lavender : EdgeTheme.textTertiary),
      ),
    );
  }

  Widget _buildEmptyCloudState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(FontAwesomeIcons.magnifyingGlassChart, size: 40, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            'Explore 10,000+ Models on Hub',
            style: TextStyle(color: EdgeTheme.textTertiary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Search by name, task, or organization.',
            style: TextStyle(color: EdgeTheme.textTertiary.withValues(alpha: 0.5), fontSize: 11),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSearchSuggest('llama-3'),
              _buildSearchSuggest('stable-diffusion'),
              _buildSearchSuggest('mistral'),
              _buildSearchSuggest('qwen'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggest(String tag) {
    return ActionChip(
      onPressed: () {
        _searchController.text = tag;
        _searchHF();
      },
      backgroundColor: EdgeTheme.surfaceColor,
      label: Text(tag, style: const TextStyle(color: EdgeTheme.lavender, fontSize: 10)),
      side: const BorderSide(color: Colors.white10),
    );
  }



  Widget _buildCategoryChip({
    required String label,
    required FaIconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? EdgeTheme.lavender.withValues(alpha: 0.1) : EdgeTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? EdgeTheme.lavender : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: isSelected ? EdgeTheme.purpleGlow(EdgeTheme.lavender) : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 14, color: isSelected ? EdgeTheme.lavender : EdgeTheme.textSecondary),
            const SizedBox(width: 10),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isSelected ? EdgeTheme.lavender : EdgeTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(ModelInfo model, bool isDownloaded, bool downloading, double progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: EdgeTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: (isDownloaded ? EdgeTheme.successGreen : EdgeTheme.lavender).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: FaIcon(
                      model.categoryIcon,
                      size: 20,
                      color: isDownloaded ? EdgeTheme.successGreen : EdgeTheme.lavender,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Title & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        model.isRemote ? 'by ${model.author ?? "Unknown"}' : model.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EdgeTheme.textTertiary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildModelCapabilityBadge(model),
                          const SizedBox(width: 8),
                          if (!model.isRemote) ...[
                            _buildMetaData('${model.sizeFormatted}'),
                            const SizedBox(width: 8),
                            _buildMetaData('${model.recommendedRamGB}GB RAM'),
                            const SizedBox(width: 8),
                            _buildMetaData('${model.contextWindow} CTX'),
                          ] else ...[
                            _buildMetaData('CLOUD CORE'),
                            const SizedBox(width: 8),
                            _buildMetaData(model.hfTaskId?.toUpperCase() ?? 'GENERAL'),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action Area
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: downloading
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          valueColor: const AlwaysStoppedAnimation<Color>(EdgeTheme.lavender),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${(progress * 100).toStringAsFixed(1)}% DOWNLOADED', style: const TextStyle(fontSize: 10, color: EdgeTheme.textTertiary)),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.circlePause, size: 20, color: EdgeTheme.textSecondary),
                            onPressed: () => _pauseDownload(model.id),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (model.isRemote) ...[
                        if (model.likes != null) ...[
                          FaIcon(FontAwesomeIcons.solidHeart, size: 10, color: EdgeTheme.errorRed.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(model.likes.toString(), style: const TextStyle(color: EdgeTheme.textTertiary, fontSize: 10)),
                          const SizedBox(width: 16),
                        ],
                        ElevatedButton.icon(
                          onPressed: () => _selectRemoteModel(model),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EdgeTheme.lavender.withValues(alpha: 0.1),
                            foregroundColor: EdgeTheme.lavender,
                            side: const BorderSide(color: EdgeTheme.lavender, width: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const FaIcon(FontAwesomeIcons.bolt, size: 12),
                          label: const Text('SELECT CLOUD CORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ] else if (isDownloaded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: EdgeTheme.successGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              FaIcon(FontAwesomeIcons.check, size: 12, color: EdgeTheme.successGreen),
                              SizedBox(width: 8),
                              Text('SYNCED', style: TextStyle(color: EdgeTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      else if (model.downloadUrl != null)
                        ElevatedButton.icon(
                          onPressed: () => _downloadModel(model),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EdgeTheme.lavender,
                            foregroundColor: EdgeTheme.primaryBackground,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const FaIcon(FontAwesomeIcons.cloudArrowDown, size: 14),
                          label: const Text('INITIALIZE CORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        )
                      else
                        const FaIcon(FontAwesomeIcons.triangleExclamation, size: 20, color: EdgeTheme.textTertiary),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaData(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: EdgeTheme.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildModelCapabilityBadge(ModelInfo model) {
    final isDiffusion = model.type == ModelType.diffusion;

    Color badgeColor;
    Color borderColor;
    String label;

    if (isDiffusion) {
      badgeColor = EdgeTheme.errorRed.withValues(alpha: 0.1);
      borderColor = EdgeTheme.errorRed.withValues(alpha: 0.3);
      label = 'IMAGE GEN';
    } else {
      badgeColor = EdgeTheme.lavender.withValues(alpha: 0.1);
      borderColor = EdgeTheme.lavender.withValues(alpha: 0.3);
      label = 'TEXT GEN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isDiffusion
              ? EdgeTheme.errorRed
              : EdgeTheme.lavender,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
