import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/model_catalog.dart';
import '../../../domain/entities/model_info.dart';
import '../../../core/di/state_providers.dart';
import '../../../core/di/repository_providers.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../core/utils/checksum_utils.dart';
import '../../../core/utils/model_metadata_extractor.dart';
import '../../../data/datasources/external_model_storage.dart';

/// My Models screen - shows downloaded/imported models ready to use
class MyModelsScreen extends ConsumerStatefulWidget {
  const MyModelsScreen({super.key});

  @override
  ConsumerState<MyModelsScreen> createState() => _MyModelsScreenState();
}

class _MyModelsScreenState extends ConsumerState<MyModelsScreen> {
  List<ModelInfo> _myModels = [];
  bool _isLoading = true;
  final Map<String, bool> _isActivating = {};

  @override
  void initState() {
    super.initState();
    _loadMyModels();
  }

  Future<void> _loadMyModels() async {
    setState(() => _isLoading = true);
    
    await ExternalModelStorageService.initialize();
    final files = await ExternalModelStorageService.getModelFiles();
    
    // Get catalog models to match names
    final catalog = AvailableModels.getAll();
    final catalogMap = <String, ModelInfo>{};
    for (final model in catalog) {
      catalogMap[model.filename.toLowerCase()] = model;
    }
    
    final models = files.map((file) {
      final filename = file.uri.pathSegments.last;
      final catalogModel = catalogMap[filename.toLowerCase()];

      // Detect runtime based on file extension
      LlmRuntime detectedRuntime = LlmRuntime.llamaCpp;
      try {
        detectedRuntime = ModelMetadataExtractor.detectRuntime(file.path);
      } catch (e) {
        // Fallback to catalog model runtime or default
        detectedRuntime = catalogModel?.runtime ?? LlmRuntime.llamaCpp;
      }

      return ModelInfo(
        id: filename.split('.').first.toLowerCase().replaceAll(' ', '_'),
        name: catalogModel?.name ?? _getNameFromFilename(filename),
        description: catalogModel?.description ?? 'Imported model',
        filename: filename,
        sizeBytes: file.lengthSync(),
        category: catalogModel?.category ?? ModelCategories.text,
        type: catalogModel?.type ?? _determineModelType(filename),
        recommendedRamGB: catalogModel?.recommendedRamGB ?? 4,
        isDownloaded: true,
        localPath: file.path,
        downloadedAt: file.lastModifiedSync(),
        contextWindow: catalogModel?.contextWindow ?? 2048,
        tags: catalogModel?.tags ?? 'imported',
        runtime: catalogModel?.runtime ?? detectedRuntime,
      );
    }).toList();
    
    if (mounted) {
      setState(() {
        _myModels = models;
        _isLoading = false;
      });
    }
  }

  String _getNameFromFilename(String filename) {
    final nameWithoutExt = filename.split('.').first;
    return nameWithoutExt
        .replaceAll(RegExp(r'[_-]'), ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1)}' 
            : '')
        .join(' ')
        .trim();
  }

  ModelType _determineModelType(String filename) {
    final lowerFilename = filename.toLowerCase();
    if (lowerFilename.contains('stable-diffusion') || 
        lowerFilename.contains('sd1') || 
        lowerFilename.contains('sdxl') ||
        lowerFilename.contains('sd-')) {
      return ModelType.diffusion;
    }
    return ModelType.text;
  }

  Future<void> _activateModel(ModelInfo model) async {
    if (_isActivating[model.id] == true) return;

    final modelPath = model.localPath;
    if (modelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model file not found')),
      );
      return;
    }

    if (model.type == ModelType.diffusion) {
      final useCloud = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: EdgeTheme.surfaceColor,
          title: const Text('Architecture Restricted', style: TextStyle(color: Colors.white)),
          content: Text('The local edge engine only supports Text Generation.\n\nWould you like to route this Image Generation task to the Hugging Face Cloud?', style: const TextStyle(color: EdgeTheme.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: EdgeTheme.lavender),
              child: const Text('Use Cloud'),
            ),
          ],
        ),
      );

      if (useCloud == true) {
        // We must map the local filename ID to a valid Hugging Face Repository ID
        String mappedHfId = 'runwayml/stable-diffusion-v1-5'; // Default fallback
        final lowercaseName = model.name.toLowerCase();

        if (lowercaseName.contains('xl')) {
          mappedHfId = 'stabilityai/stable-diffusion-xl-base-1.0';
        } else if (lowercaseName.contains('flux')) {
          mappedHfId = 'black-forest-labs/FLUX.1-schnell';
        }

        final remoteModel = model.copyWith(
          isRemote: true,
          id: mappedHfId,  // Overwrite local fake ID with real HF ID
          name: '${model.name} (Cloud Node)',
        );

        ref.read(activeModelProvider.notifier).state = remoteModel;
        ref.read(settingsProvider.notifier).updateActiveModel(remoteModel.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                   const FaIcon(FontAwesomeIcons.cloud, color: Colors.white, size: 16),
                   const SizedBox(width: 12),
                   Expanded(child: Text('Routed to HF Cloud: $mappedHfId')),
                ],
              ),
              backgroundColor: EdgeTheme.lavender,
            ),
          );
        }
      }
      return;
    }

    // Show engine selection dialog
    final selectedRuntime = await showDialog<LlmRuntime>(
      context: context,
      builder: (context) => _EngineSelectionDialog(modelPath: modelPath),
    );

    if (selectedRuntime == null) return; // User cancelled

    setState(() => _isActivating[model.id] = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: EdgeTheme.surfaceColor,
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: EdgeTheme.lavender),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Calibrating Core: ${model.name}...\nEngine: ${selectedRuntime.name.toUpperCase()}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        duration: const Duration(minutes: 2),
      ),
    );

    try {
      final correctionRepo = ref.read(correctionRepositoryProvider);
      
      // Determine if we need to force the engine
      final detectedRuntime = ModelMetadataExtractor.detectRuntime(modelPath);
      final forceEngine = detectedRuntime != selectedRuntime;

      await correctionRepo.initializeModelWithEngine(
        modelPath,
        runtime: selectedRuntime,
        forceEngine: forceEngine,
      );

      ref.read(activeModelProvider.notifier).state = model;
      ref.read(settingsProvider.notifier).updateActiveModel(model.id);

      if (mounted) {
        setState(() => _isActivating[model.id] = false);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const FaIcon(FontAwesomeIcons.checkDouble, color: Colors.white, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${model.name} activated\nEngine: ${selectedRuntime.name.toUpperCase()}',
                  ),
                ),
              ],
            ),
            backgroundColor: EdgeTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActivating[model.id] = false);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calibration failed: $e'),
            backgroundColor: EdgeTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _stopModel() async {
    final activeModel = ref.read(activeModelProvider);
    if (activeModel == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EdgeTheme.surfaceColor,
        title: const Text('Deactivate Core', style: TextStyle(color: Colors.white)),
        content: Text('Deactivate ${activeModel.name} and free neural memory?', style: const TextStyle(color: EdgeTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: EdgeTheme.errorRed),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final correctionRepo = ref.read(correctionRepositoryProvider);
        await correctionRepo.unloadModel();
        ref.read(activeModelProvider.notifier).state = null;
        ref.read(settingsProvider.notifier).updateActiveModel('');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${activeModel.name} deactivated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operation failed: $e'), backgroundColor: EdgeTheme.errorRed),
          );
        }
      }
    }
  }

  Future<void> _deleteModel(ModelInfo model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EdgeTheme.surfaceColor,
        title: const Text('Purge Core Data', style: TextStyle(color: Colors.white)),
        content: Text('Permanently delete ${model.name}? This will reclaim ${model.sizeFormatted}.', style: const TextStyle(color: EdgeTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: EdgeTheme.errorRed),
            child: const Text('Purge'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (model.localPath != null) {
        final file = File(model.localPath!);
        if (await file.exists()) await file.delete();
      }
      await _loadMyModels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${model.name} purged from memory')),
        );
      }
    }
  }

  Future<void> _importModel() async {
    final repo = ref.read(modelRepositoryProvider);
    final importedModel = await repo.importModelFromDevice();
    
    if (importedModel != null && mounted) {
      await _loadMyModels();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${importedModel.name} imported successfully.'),
          backgroundColor: EdgeTheme.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeModel = ref.watch(activeModelProvider);

    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Core Intelligence'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.plus, size: 18),
            onPressed: _importModel,
            tooltip: 'Import Core',
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const FaIcon(FontAwesomeIcons.barsStaggered, size: 18),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: EdgeTheme.lavender))
          : Column(
              children: [
                // Active core status
                if (activeModel != null)
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: EdgeTheme.lavender.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.3)),
                      boxShadow: EdgeTheme.purpleGlow(EdgeTheme.lavender.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: EdgeTheme.lavender,
                            shape: BoxShape.circle,
                          ),
                          child: const FaIcon(FontAwesomeIcons.bolt, color: EdgeTheme.primaryBackground, size: 18),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACTIVE INTELLIGENCE',
                                style: TextStyle(
                                  color: EdgeTheme.lavender.withValues(alpha: 0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeModel.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const FaIcon(FontAwesomeIcons.circleStop, color: EdgeTheme.errorRed, size: 24),
                          onPressed: _stopModel,
                        ),
                      ],
                    ),
                  ),

                // System Stats
                FutureBuilder<int>(
                  future: ExternalModelStorageService.getStorageUsed(),
                  builder: (context, snapshot) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          FaIcon(FontAwesomeIcons.microchip, color: EdgeTheme.textTertiary, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            '${_myModels.length} CORES LOADED • ${snapshot.hasData ? ChecksumUtils.formatFileSize(snapshot.data!) : '...'} SYNCED',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: EdgeTheme.textTertiary,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Models list
                Expanded(
                  child: _myModels.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _myModels.length,
                          itemBuilder: (context, index) {
                            final model = _myModels[index];
                            final isActive = activeModel?.id == model.id;
                            final activating = _isActivating[model.id] == true;

                            return _buildModelCard(model, isActive, activating);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: EdgeTheme.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: const FaIcon(FontAwesomeIcons.boxOpen, size: 40, color: EdgeTheme.textTertiary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Library Empty',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Import a model core to begin calibration.',
            style: TextStyle(color: EdgeTheme.textTertiary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _importModel,
            icon: const FaIcon(FontAwesomeIcons.fileImport, size: 14),
            label: const Text('IMPORT CORE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: EdgeTheme.lavender,
              foregroundColor: EdgeTheme.primaryBackground,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(ModelInfo model, bool isActive, bool activating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: EdgeTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? EdgeTheme.lavender : Colors.white.withValues(alpha: 0.05),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive ? EdgeTheme.purpleGlow(EdgeTheme.lavender.withValues(alpha: 0.2)) : [],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: (isActive ? EdgeTheme.lavender : EdgeTheme.textTertiary).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: FaIcon(
              model.categoryIcon,
              size: 20,
              color: isActive ? EdgeTheme.lavender : EdgeTheme.textTertiary,
            ),
          ),
        ),
        title: Text(
          model.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              '${model.sizeFormatted} • ${model.recommendedRamGB}GB RAM • ${model.contextWindow} CTX',
              style: const TextStyle(color: EdgeTheme.textTertiary, fontSize: 11),
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: EdgeTheme.successGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Text('ONLINE & READY', style: TextStyle(color: EdgeTheme.successGreen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ],
                ),
              ),
          ],
        ),
        trailing: activating
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: EdgeTheme.lavender))
            : PopupMenuButton<String>(
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16, color: EdgeTheme.textTertiary),
                color: EdgeTheme.surfaceColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) {
                  if (value == 'activate') _activateModel(model);
                  if (value == 'delete') _deleteModel(model);
                },
                itemBuilder: (context) => [
                  if (!isActive)
                    const PopupMenuItem(
                      value: 'activate',
                      child: Row(children: [
                        FaIcon(FontAwesomeIcons.play, size: 14),
                        SizedBox(width: 12),
                        Text('Calibrate Core', style: TextStyle(fontSize: 13)),
                      ]),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      FaIcon(FontAwesomeIcons.trashCan, size: 14, color: EdgeTheme.errorRed),
                      SizedBox(width: 12),
                      Text('Purge Data', style: TextStyle(color: EdgeTheme.errorRed, fontSize: 13)),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Dialog widget for selecting the inference engine
class _EngineSelectionDialog extends StatefulWidget {
  final String modelPath;

  const _EngineSelectionDialog({required this.modelPath});

  @override
  State<_EngineSelectionDialog> createState() => _EngineSelectionDialogState();
}

class _EngineSelectionDialogState extends State<_EngineSelectionDialog> {
  LlmRuntime? _selectedRuntime;

  @override
  void initState() {
    super.initState();
    // Auto-select based on file extension as default
    try {
      _selectedRuntime = ModelMetadataExtractor.detectRuntime(widget.modelPath);
    } catch (e) {
      _selectedRuntime = LlmRuntime.llamaCpp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detectedRuntime = ModelMetadataExtractor.detectRuntime(widget.modelPath);
    final isForcing = _selectedRuntime != detectedRuntime;

    return AlertDialog(
      backgroundColor: EdgeTheme.surfaceColor,
      title: const Text(
        'Select Inference Engine',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File: ${widget.modelPath.split('/').last}',
              style: const TextStyle(color: EdgeTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'DETECTED FORMAT:',
              style: TextStyle(
                color: EdgeTheme.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EdgeTheme.lavender.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.fileCode, color: EdgeTheme.lavender, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      detectedRuntime.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SELECT ENGINE:',
              style: TextStyle(
                color: EdgeTheme.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildEngineOption(
              runtime: LlmRuntime.llamaCpp,
              icon: FontAwesomeIcons.fire,
              label: 'llama.cpp',
              description: 'GGUF format • CPU/GPU • Wide model support',
              recommended: detectedRuntime == LlmRuntime.llamaCpp,
            ),
            if (isForcing)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EdgeTheme.warningOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: EdgeTheme.warningOrange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.triangleExclamation,
                        color: EdgeTheme.warningOrange,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Forcing engine different from detected format may fail!',
                          style: const TextStyle(
                            color: EdgeTheme.warningOrange,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedRuntime),
          style: ElevatedButton.styleFrom(
            backgroundColor: EdgeTheme.lavender,
            foregroundColor: EdgeTheme.primaryBackground,
          ),
          child: const Text('LOAD MODEL'),
        ),
      ],
    );
  }

  Widget _buildEngineOption({
    required LlmRuntime runtime,
    required FaIconData icon,
    required String label,
    required String description,
    required bool recommended,
  }) {
    final isSelected = _selectedRuntime == runtime;

    return GestureDetector(
      onTap: () => setState(() => _selectedRuntime = runtime),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? EdgeTheme.lavender.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? EdgeTheme.lavender : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? EdgeTheme.lavender
                    : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                icon,
                size: 16,
                color: isSelected
                    ? EdgeTheme.primaryBackground
                    : EdgeTheme.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : EdgeTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: EdgeTheme.successGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              color: EdgeTheme.successGreen,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: EdgeTheme.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const FaIcon(
                FontAwesomeIcons.circleCheck,
                color: EdgeTheme.lavender,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
