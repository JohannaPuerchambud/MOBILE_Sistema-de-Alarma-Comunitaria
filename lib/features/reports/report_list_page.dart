import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'report_model.dart';
import 'report_service.dart';

enum _ActivityFilter { all, reports, emergencies }

class ReportListPage extends StatefulWidget {
  final String? initialActivityId;

  const ReportListPage({super.key, this.initialActivityId});

  @override
  State<ReportListPage> createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage> {
  final ReportService _service = ReportService();

  bool loading = true;
  String? error;
  List<NeighborhoodActivity> activity = [];
  _ActivityFilter selectedFilter = _ActivityFilter.all;
  bool _initialActivityOpened = false;

  List<NeighborhoodActivity> get filteredActivity {
    return switch (selectedFilter) {
      _ActivityFilter.all => activity,
      _ActivityFilter.reports =>
        activity.where((item) => !item.isEmergency).toList(),
      _ActivityFilter.emergencies =>
        activity.where((item) => item.isEmergency).toList(),
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await _service.getNeighborhoodActivity();
      if (!mounted) return;
      setState(() => activity = data);
      _openInitialActivity(data);
    } catch (loadError) {
      if (!mounted) return;
      setState(() => error = ReportService.userMessageForError(loadError));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _openInitialActivity(List<NeighborhoodActivity> items) {
    final activityId = widget.initialActivityId;
    if (_initialActivityOpened || activityId == null || activityId.isEmpty) {
      return;
    }

    NeighborhoodActivity? selected;
    for (final item in items) {
      if (item.activityId == activityId) {
        selected = item;
        break;
      }
    }
    if (selected == null) return;

    _initialActivityOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showActivityDetail(selected!);
    });
  }

  String _formatDate(DateTime value) {
    return "${value.day.toString().padLeft(2, '0')}/"
        "${value.month.toString().padLeft(2, '0')}/"
        "${value.year} ${value.hour.toString().padLeft(2, '0')}:"
        "${value.minute.toString().padLeft(2, '0')}";
  }

  Color _activityColor(NeighborhoodActivity item) {
    return item.isEmergency ? const Color(0xFFE5484D) : const Color(0xFFF59E0B);
  }

  IconData _activityIcon(NeighborhoodActivity item) {
    return item.isEmergency
        ? Icons.campaign_rounded
        : Icons.warning_amber_rounded;
  }

  String _activityLabel(NeighborhoodActivity item) {
    return item.isEmergency ? 'EMERGENCIA' : 'REPORTE';
  }

  Future<void> _openLocation(NeighborhoodActivity item) async {
    if (!item.hasLocation) return;

    final uri = Uri.parse(
      'https://maps.google.com/?q=${item.latitude},${item.longitude}',
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage('No se pudo abrir la ubicación.');
      }
    } catch (_) {
      if (mounted) _showMessage('No se pudo abrir la ubicación.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showFullImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text(
              'Evidencia',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const CircularProgressIndicator(color: Colors.white);
                },
                errorBuilder: (_, _, _) => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 56,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No se pudo cargar la evidencia.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showActivityDetail(NeighborhoodActivity item) {
    final color = _activityColor(item);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.52,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _activityIcon(item),
                          color: color,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activityLabel(item),
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (item.hasImage) ...[
                    GestureDetector(
                      onTap: () => _showFullImage(item.imageUrl!),
                      child: Hero(
                        tag: 'activity-image-${item.activityId}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            item.imageUrl!,
                            width: double.infinity,
                            height: 250,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 250,
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: color,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, _, _) => Container(
                              height: 250,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _DetailSection(
                    label: item.isEmergency ? 'MOTIVO' : 'DETALLE',
                    child: Text(
                      item.description,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailSection(
                    label: 'INFORMACIÓN',
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.person_outline_rounded,
                          text: item.authorName,
                        ),
                        if ((item.address ?? '').trim().isNotEmpty)
                          _DetailRow(
                            icon: Icons.location_on_outlined,
                            text: item.address!,
                          ),
                        _DetailRow(
                          icon: Icons.schedule_rounded,
                          text: _formatDate(item.createdAt),
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  if (item.hasLocation) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => _openLocation(item),
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text(
                          'Ver ubicación en Google Maps',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilter(String label, _ActivityFilter filter, IconData icon) {
    final selected = selectedFilter == filter;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ChoiceChip(
          selected: selected,
          onSelected: (_) => setState(() => selectedFilter = filter),
          showCheckmark: false,
          avatar: Icon(
            icon,
            size: 17,
            color: selected ? Colors.white : const Color(0xFF667085),
          ),
          label: Text(label),
          labelStyle: TextStyle(
            color: selected ? Colors.white : const Color(0xFF475467),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          selectedColor: const Color(0xFF667EEA),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: selected ? const Color(0xFF667EEA) : const Color(0xFFE4E7EC),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        ),
      ),
    );
  }

  Widget _buildActivityCard(NeighborhoodActivity item) {
    final color = _activityColor(item);

    return Card(
      elevation: 1.5,
      shadowColor: Colors.black12,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEAECF0)),
      ),
      child: InkWell(
        onTap: () => _showActivityDetail(item),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.hasImage) ...[
                        Hero(
                          tag: 'activity-image-${item.activityId}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              item.imageUrl!,
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  width: 92,
                                  height: 92,
                                  color: Colors.grey.shade100,
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) => Container(
                                width: 92,
                                height: 92,
                                color: Colors.grey.shade100,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 13),
                      ] else ...[
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            _activityIcon(item),
                            color: color,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 13),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _activityLabel(item),
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDate(item.createdAt),
                                  style: const TextStyle(
                                    color: Color(0xFF98A2B3),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1D2939),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 15,
                                  color: Color(0xFF98A2B3),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    item.authorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF667085),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF98A2B3),
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = switch (selectedFilter) {
      _ActivityFilter.all => 'No hay actividad registrada todavía.',
      _ActivityFilter.reports => 'No hay reportes sospechosos.',
      _ActivityFilter.emergencies => 'No hay emergencias registradas.',
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        const Icon(Icons.verified_outlined, size: 72, color: Color(0xFF98A2B3)),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Tu barrio está tranquilo',
            style: TextStyle(
              color: Color(0xFF344054),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF98A2B3)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleActivity = filteredActivity;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Actividad del barrio',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
            child: Row(
              children: [
                _buildFilter(
                  'Todos',
                  _ActivityFilter.all,
                  Icons.view_agenda_outlined,
                ),
                _buildFilter(
                  'Reportes',
                  _ActivityFilter.reports,
                  Icons.warning_amber_rounded,
                ),
                _buildFilter(
                  'Emergencias',
                  _ActivityFilter.emergencies,
                  Icons.campaign_outlined,
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF667EEA)),
                  )
                : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            color: Colors.redAccent,
                            size: 52,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF667EEA),
                    onRefresh: _load,
                    child: visibleActivity.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: visibleActivity.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) =>
                                _buildActivityCard(visibleActivity[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667EEA),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool showDivider;

  const _DetailRow({
    required this.icon,
    required this.text,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF667EEA), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: Divider(height: 1, color: Color(0xFFEAECF0)),
          ),
      ],
    );
  }
}
