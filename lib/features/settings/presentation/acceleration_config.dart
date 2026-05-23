import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../data/datasources/llm_service.dart';
import '../../../data/datasources/llama_cpp_engine.dart';
import '../../../domain/entities/model_info.dart';

/// GPU/NPU acceleration configuration widget
class AccelerationConfig extends ConsumerStatefulWidget {
  const AccelerationConfig({super.key});

  @override
  ConsumerState<AccelerationConfig> createState() => _AccelerationConfigState();
}

class _AccelerationConfigState extends ConsumerState<AccelerationConfig> {
  List<LlmRuntime> _availableRuntimes = [];
  Map<String, dynamic> _engineInfo = {};
  bool _isLoading = true;
  LlmRuntime? _selectedRuntime;

  @override
  void initState() {
    super.initState();
    _loadAccelerationInfo();
  }

  Future<void> _loadAccelerationInfo() async {
    setState(() => _isLoading = true);

    try {
      final runtimes = await LLMService.getAvailableRuntimes();
      final service = LLMService();
      final info = await service.getEngineInfo();

      setState(() {
        _availableRuntimes = runtimes;
        _engineInfo = info;
        _selectedRuntime = service.activeRuntime;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EdgeTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.microchip,
                color: EdgeTheme.lavender,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                'ACCELERATION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const FaIcon(
                  FontAwesomeIcons.arrowsRotate,
                  color: EdgeTheme.lavender,
                  size: 14,
                ),
                onPressed: _loadAccelerationInfo,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: EdgeTheme.lavender,
                  strokeWidth: 2,
                ),
              ),
            )
          else ...[
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildRuntimeSelector(),
            const SizedBox(height: 16),
            _buildAccelerationInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final hasGpu = _availableRuntimes.any((r) =>
        r == LlmRuntime.llamaCppCuda ||
        r == LlmRuntime.llamaCppMetal ||
        r == LlmRuntime.llamaCppVulkan ||
        r == LlmRuntime.llamaCppOpenCL);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EdgeTheme.lavender.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasGpu ? FontAwesomeIcons.display : FontAwesomeIcons.xmark,
                      color: hasGpu ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasGpu ? 'GPU Available' : 'GPU Not Detected',
                      style: TextStyle(
                        color: hasGpu ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RUNTIME ENGINE',
          style: TextStyle(
            color: EdgeTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<LlmRuntime>(
          value: _selectedRuntime,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: EdgeTheme.secondarySurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: _availableRuntimes.map((runtime) {
            return DropdownMenuItem(
              value: runtime,
              child: Row(
                children: [
                  _getRuntimeIcon(runtime),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getRuntimeName(runtime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getRuntimeDescription(runtime),
                          style: TextStyle(
                            color: EdgeTheme.textSecondary,
                            fontSize: 10,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedRuntime = value);
              // TODO: Save to settings and reload model
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected ${_getRuntimeName(value)} runtime'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildAccelerationInfo() {
    if (_engineInfo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EdgeTheme.lavender.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENGINE INFORMATION',
            style: TextStyle(
              color: EdgeTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Engine', _engineInfo['engine'] ?? 'N/A'),
          _buildInfoRow('Runtime', _engineInfo['runtime'] ?? 'none'),
          if (_engineInfo['gpuBackends'] != null)
            _buildInfoRow(
              'GPU Backends',
              (_engineInfo['gpuBackends'] as List).join(', '),
            ),
          if (_engineInfo['recommendedGpuLayers'] != null)
            _buildInfoRow(
              'Recommended GPU Layers',
              _engineInfo['recommendedGpuLayers'].toString(),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: EdgeTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getRuntimeIcon(LlmRuntime runtime) {
    FaIconData icon;
    Color color;

    switch (runtime) {
      case LlmRuntime.llamaCpp:
        icon = FontAwesomeIcons.brain;
        color = Colors.orange;
        break;
      case LlmRuntime.llamaCppCuda:
        icon = FontAwesomeIcons.microchip;
        color = Colors.green;
        break;
      case LlmRuntime.llamaCppMetal:
        icon = FontAwesomeIcons.apple;
        color = Colors.white;
        break;
      case LlmRuntime.llamaCppVulkan:
        icon = FontAwesomeIcons.gamepad;
        color = Colors.purple;
        break;
      case LlmRuntime.llamaCppOpenCL:
        icon = FontAwesomeIcons.microchip;
        color = Colors.cyan;
        break;
    }

    return FaIcon(icon, color: color, size: 18);
  }

  String _getRuntimeName(LlmRuntime runtime) {
    switch (runtime) {
      case LlmRuntime.llamaCpp:
        return 'llama.cpp (CPU)';
      case LlmRuntime.llamaCppCuda:
        return 'llama.cpp (CUDA)';
      case LlmRuntime.llamaCppMetal:
        return 'llama.cpp (Metal)';
      case LlmRuntime.llamaCppVulkan:
        return 'llama.cpp (Vulkan)';
      case LlmRuntime.llamaCppOpenCL:
        return 'llama.cpp (OpenCL)';
    }
    return runtime.name;
  }

  String _getRuntimeDescription(LlmRuntime runtime) {
    switch (runtime) {
      case LlmRuntime.llamaCpp:
        return 'Industry-standard GGUF inference (CPU)';
      case LlmRuntime.llamaCppCuda:
        return 'NVIDIA GPU acceleration (CUDA)';
      case LlmRuntime.llamaCppMetal:
        return 'Apple Silicon GPU acceleration (Metal)';
      case LlmRuntime.llamaCppVulkan:
        return 'Cross-platform GPU acceleration (Vulkan)';
      case LlmRuntime.llamaCppOpenCL:
        return 'OpenCL GPU acceleration (Adreno/Intel)';
    }
    return '';
  }
}
