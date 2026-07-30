import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/exercise_repository.dart';
import '../../models/exercise.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import 'exercise_detail_screen.dart';
import 'personal_exercise_form_screen.dart';

/// UI.pdf "Kho bài tập" (Personal Exercise Library) — SRS §4.5.
/// Tabs: Tất cả / Đã tạo / Yêu thích / Lịch sử tập.
class PersonalExerciseLibraryScreen extends StatefulWidget {
  const PersonalExerciseLibraryScreen({
    super.key,
    required this.personalExerciseRepository,
    required this.exerciseRepository,
    required this.favoriteRepository,
    required this.uid,
  });

  final PersonalExerciseRepository personalExerciseRepository;
  final ExerciseRepository exerciseRepository;
  final FavoriteExerciseRepository favoriteRepository;
  final String uid;

  @override
  State<PersonalExerciseLibraryScreen> createState() =>
      _PersonalExerciseLibraryScreenState();
}

class _LibraryItem {
  _LibraryItem.personal(PersonalExercise value)
    : personal = value,
      template = null,
      favorite = value.isFavorite;
  const _LibraryItem.template(this.template, this.favorite) : personal = null;

  final PersonalExercise? personal;
  final Exercise? template;
  final bool favorite;

  String get id => (personal?.id ?? template?.id)!;
  String get name => (personal?.name ?? template?.name)!;
  String get muscleLabel => (personal?.primaryMuscle ?? template?.primaryMuscle)!.label;
  bool get isPersonal => personal != null;
}

class _PersonalExerciseLibraryScreenState
    extends State<PersonalExerciseLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 4, vsync: this);
  final _search = TextEditingController();
  String _query = '';

  List<PersonalExercise>? _personal;
  List<Exercise>? _templates;
  Set<String> _favoriteIds = {};

  StreamSubscription<List<PersonalExercise>>? _personalSub;
  StreamSubscription<List<Exercise>>? _templateSub;
  StreamSubscription<Set<String>>? _favoriteSub;

  @override
  void initState() {
    super.initState();
    _personalSub = widget.personalExerciseRepository
        .watchPersonalExercises(widget.uid)
        .listen((value) => setState(() => _personal = value));
    _templateSub = widget.exerciseRepository.watchExercises().listen(
      (value) => setState(() => _templates = value),
    );
    _favoriteSub = widget.favoriteRepository.watchFavoriteIds(widget.uid).listen(
      (value) => setState(() => _favoriteIds = value),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    _personalSub?.cancel();
    _templateSub?.cancel();
    _favoriteSub?.cancel();
    super.dispose();
  }

  bool get _loading => _personal == null || _templates == null;

  List<_LibraryItem> get _allItems {
    if (_loading) return const [];
    final items = <_LibraryItem>[
      for (final p in _personal!) _LibraryItem.personal(p),
      for (final t in _templates!.where((t) => _favoriteIds.contains(t.id)))
        _LibraryItem.template(t, true),
    ];
    if (_query.trim().isEmpty) return items;
    final q = _query.trim().toLowerCase();
    return items.where((item) => item.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _openPersonal(PersonalExercise personal) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalExerciseFormScreen(
          repository: widget.personalExerciseRepository,
          uid: widget.uid,
          initial: personal,
        ),
      ),
    );
  }

  void _openTemplate(Exercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exercise: exercise,
          favorite: _favoriteIds.contains(exercise.id),
          onToggleFavorite: () => widget.favoriteRepository.setFavorite(
            widget.uid,
            exercise.id,
            !_favoriteIds.contains(exercise.id),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho bài tập'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Đã tạo'),
            Tab(text: 'Yêu thích'),
            Tab(text: 'Lịch sử tập'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PersonalExerciseFormScreen(
              repository: widget.personalExerciseRepository,
              uid: widget.uid,
            ),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Thêm bài tập'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quản lý và tùy chỉnh danh sách bài tập cá nhân của bạn.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tìm kiếm bài tập...',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _list(_allItems, emptyMessage: 'Chưa có bài tập nào.'),
                      _list(
                        _allItems.where((item) => item.isPersonal).toList(),
                        emptyMessage: 'Bạn chưa tạo bài tập cá nhân nào.',
                      ),
                      _list(
                        _allItems.where((item) => item.favorite).toList(),
                        emptyMessage: 'Chưa có bài tập yêu thích nào.',
                      ),
                      const _HistoryPlaceholder(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<_LibraryItem> items, {required String emptyMessage}) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.fitness_center_outlined,
        title: 'Trống',
        message: emptyMessage,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            onTap: item.isPersonal
                ? () => _openPersonal(item.personal!)
                : () => _openTemplate(item.template!),
            title: Text(item.name),
            subtitle: Text(item.muscleLabel),
            trailing: Chip(
              visualDensity: VisualDensity.compact,
              label: Text(item.isPersonal ? 'Cá nhân' : 'Hệ thống'),
              backgroundColor: item.isPersonal
                  ? AppColors.paleBlue
                  : AppColors.input,
            ),
          ),
        );
      },
    );
  }
}

class _HistoryPlaceholder extends StatelessWidget {
  const _HistoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.history,
      title: 'Chưa có lịch sử',
      message:
          'Lịch sử buổi tập sẽ hiển thị ở đây khi tích hợp dữ liệu buổi tập '
          'hoàn thành (WorkoutCompletion) từ chương trình.',
    );
  }
}
