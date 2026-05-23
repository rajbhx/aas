import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

/// Architecture types for local execution
enum ModelType { text, diffusion, unknown }

/// Supported runtime engines for local inference.
enum LlmRuntime {
  /// Standard GGUF support via llama.cpp (CPU).
  llamaCpp,

  /// llama.cpp with CUDA GPU acceleration (NVIDIA).
  llamaCppCuda,

  /// llama.cpp with Metal GPU acceleration (Apple).
  llamaCppMetal,

  /// llama.cpp with Vulkan GPU acceleration (Cross-platform).
  llamaCppVulkan,

  /// llama.cpp with OpenCL GPU acceleration (Android Adreno/Intel).
  llamaCppOpenCL,
}

/// Model categories for different AI tasks
class ModelCategories {
  static const String text = 'Text & Writing';
  static const String code = 'Code & Programming';
  static const String math = 'Math & Science';
  static const String creative = 'Creative & Art';
  static const String translation = 'Translation';
  static const String reasoning = 'Reasoning & Logic';
}

/// Model information entity - Unified for both catalog and runtime state
class ModelInfo {
  final String id;
  final String name;
  final String description;
  final String filename;
  final int sizeBytes;
  final String? downloadUrl;
  final String category;
  final String? url;
  final int recommendedRamGB;
  final ModelType type;
  final bool isDownloaded;
  final bool isActive;
  final String? localPath;
  final DateTime? downloadedAt;
  final String tags;
  final int contextWindow;
  final bool isRemote;
  final String? author;
  final int? likes;
  final String? hfTaskId;
  final bool isVision;
  final LlmRuntime runtime;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.filename,
    required this.sizeBytes,
    this.downloadUrl,
    required this.category,
    this.url,
    required this.recommendedRamGB,
    this.type = ModelType.text,
    this.isDownloaded = false,
    this.isActive = false,
    this.localPath,
    this.downloadedAt,
    this.tags = '',
    this.contextWindow = 2048,
    this.isRemote = false,
    this.author,
    this.likes,
    this.hfTaskId,
    this.isVision = false,
    this.runtime = LlmRuntime.llamaCpp,
  });

  /// Get human-readable size
  String get sizeFormatted {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get model category icon
  FaIconData get categoryIcon {
    switch (category) {
      case ModelCategories.text:
        return FontAwesomeIcons.penNib;
      case ModelCategories.code:
        return FontAwesomeIcons.code;
      case ModelCategories.math:
        return FontAwesomeIcons.squareRootVariable;
      case ModelCategories.creative:
        return FontAwesomeIcons.palette;
      case ModelCategories.translation:
        return FontAwesomeIcons.globe;
      case ModelCategories.reasoning:
        return FontAwesomeIcons.brain;
      default:
        return FontAwesomeIcons.robot;
    }
  }

  /// Helper to determine if it's a diffusion model
  bool get isDiffusionModel => type == ModelType.diffusion;

  /// Copy with new values
  ModelInfo copyWith({
    String? id,
    String? name,
    String? description,
    String? filename,
    int? sizeBytes,
    String? downloadUrl,
    String? category,
    String? url,
    int? recommendedRamGB,
    ModelType? type,
    bool? isDownloaded,
    bool? isActive,
    String? localPath,
    DateTime? downloadedAt,
    String? tags,
    int? contextWindow,
    bool? isRemote,
    String? author,
    int? likes,
    String? hfTaskId,
    bool? isVision,
    LlmRuntime? runtime,
  }) {
    return ModelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      filename: filename ?? this.filename,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      category: category ?? this.category,
      url: url ?? this.url,
      recommendedRamGB: recommendedRamGB ?? this.recommendedRamGB,
      type: type ?? this.type,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isActive: isActive ?? this.isActive,
      localPath: localPath ?? this.localPath,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      tags: tags ?? this.tags,
      contextWindow: contextWindow ?? this.contextWindow,
      isRemote: isRemote ?? this.isRemote,
      author: author ?? this.author,
      likes: likes ?? this.likes,
      hfTaskId: hfTaskId ?? this.hfTaskId,
      isVision: isVision ?? this.isVision,
      runtime: runtime ?? this.runtime,
    );
  }
}
