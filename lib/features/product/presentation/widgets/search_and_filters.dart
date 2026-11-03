import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/filter_providers.dart';

class SearchAndFilters extends ConsumerStatefulWidget {
  const SearchAndFilters({super.key});

  @override
  ConsumerState<SearchAndFilters> createState() => _SearchAndFiltersState();
}

class _SearchAndFiltersState extends ConsumerState<SearchAndFilters> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchCtrl.clear();
        ref.read(searchQueryProvider.notifier).clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusFilter = ref.watch(statusFilterProvider);
    final typeFilter = ref.watch(typeFilterProvider);
    final counts = ref.watch(statusCountsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ============ BARRA DE BUSCA ============
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: _showSearch
                    ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, lote, código...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(searchQueryProvider.notifier).clear();
                      },
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    ref.read(searchQueryProvider.notifier).update(value);
                  },
                )
                    : const SizedBox.shrink(),
              ),
              if (!_showSearch)
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Buscar',
                  onPressed: _toggleSearch,
                )
              else
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Fechar busca',
                  onPressed: _toggleSearch,
                ),
            ],
          ),
        ),

        // ============ CHIPS DE STATUS ============
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _StatusChip(
                filter: StatusFilter.all,
                count: counts[StatusFilter.all] ?? 0,
                selected: statusFilter == StatusFilter.all,
              ),
              const SizedBox(width: 6),
              _StatusChip(
                filter: StatusFilter.expired,
                count: counts[StatusFilter.expired] ?? 0,
                selected: statusFilter == StatusFilter.expired,
                color: Colors.red,
              ),
              const SizedBox(width: 6),
              _StatusChip(
                filter: StatusFilter.expiringSoon,
                count: counts[StatusFilter.expiringSoon] ?? 0,
                selected: statusFilter == StatusFilter.expiringSoon,
                color: Colors.orange,
              ),
              const SizedBox(width: 6),
              _StatusChip(
                filter: StatusFilter.ok,
                count: counts[StatusFilter.ok] ?? 0,
                selected: statusFilter == StatusFilter.ok,
                color: Colors.green,
              ),
            ],
          ),
        ),

        // ============ CHIPS DE TIPO ============
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _TypeChip(
                icon: Icons.apps,
                label: 'Todos',
                value: null,
                selected: typeFilter == null,
              ),
              const SizedBox(width: 6),
              _TypeChip(
                icon: Icons.restaurant,
                label: 'Alimentos',
                value: 0,
                selected: typeFilter == 0,
              ),
              const SizedBox(width: 6),
              _TypeChip(
                icon: Icons.medication,
                label: 'Medicamentos',
                value: 1,
                selected: typeFilter == 1,
              ),
              const SizedBox(width: 6),
              _TypeChip(
                icon: Icons.spa,
                label: 'Beleza',
                value: 2,
                selected: typeFilter == 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends ConsumerWidget {
  final StatusFilter filter;
  final int count;
  final bool selected;
  final Color? color;

  const _StatusChip({
    required this.filter,
    required this.count,
    required this.selected,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseColor = color ?? Theme.of(context).colorScheme.primary;
    return FilterChip(
      label: Text(count > 0 ? '${filter.label} ($count)' : filter.label),
      selected: selected,
      showCheckmark: false,
      selectedColor: baseColor.withValues(alpha: 0.2),
      side: BorderSide(
        color: selected ? baseColor : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        color: selected ? baseColor : Colors.grey.shade800,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      onSelected: (_) {
        ref.read(statusFilterProvider.notifier).set(filter);
      },
    );
  }
}

class _TypeChip extends ConsumerWidget {
  final IconData icon;
  final String label;
  final int? value;
  final bool selected;

  const _TypeChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseColor = Theme.of(context).colorScheme.primary;
    return FilterChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? baseColor : Colors.grey.shade600,
      ),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: baseColor.withValues(alpha: 0.2),
      side: BorderSide(
        color: selected ? baseColor : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        color: selected ? baseColor : Colors.grey.shade800,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      onSelected: (_) {
        ref.read(typeFilterProvider.notifier).set(value);
      },
    );
  }
}