// Enum keys are fixed English/ASCII strings (docs/TV2_TASKS.md §3) so they
// match 1:1 with what's already seeded in Firestore. Vietnamese labels below
// are a UI-only display concern — never stored.

enum Muscle {
  nguc,
  lungTren,
  lungDuoi,
  vaiTruoc,
  vaiGiua,
  vaiSau,
  tayTruoc,
  taySau,
  duiTruoc,
  duiSau,
  mong,
  bapChan,
  bung;

  static const _keys = {
    Muscle.nguc: 'nguc',
    Muscle.lungTren: 'lung_tren',
    Muscle.lungDuoi: 'lung_duoi',
    Muscle.vaiTruoc: 'vai_truoc',
    Muscle.vaiGiua: 'vai_giua',
    Muscle.vaiSau: 'vai_sau',
    Muscle.tayTruoc: 'tay_truoc',
    Muscle.taySau: 'tay_sau',
    Muscle.duiTruoc: 'dui_truoc',
    Muscle.duiSau: 'dui_sau',
    Muscle.mong: 'mong',
    Muscle.bapChan: 'bap_chan',
    Muscle.bung: 'bung',
  };

  static const _labels = {
    Muscle.nguc: 'Ngực',
    Muscle.lungTren: 'Lưng trên',
    Muscle.lungDuoi: 'Lưng dưới',
    Muscle.vaiTruoc: 'Vai trước',
    Muscle.vaiGiua: 'Vai giữa',
    Muscle.vaiSau: 'Vai sau',
    Muscle.tayTruoc: 'Tay trước',
    Muscle.taySau: 'Tay sau',
    Muscle.duiTruoc: 'Đùi trước',
    Muscle.duiSau: 'Đùi sau',
    Muscle.mong: 'Mông',
    Muscle.bapChan: 'Bắp chân',
    Muscle.bung: 'Bụng',
  };

  String get key => _keys[this]!;
  String get label => _labels[this]!;

  static Muscle? fromKey(String? key) =>
      _keys.entries.where((e) => e.value == key).map((e) => e.key).firstOrNull;
}

enum Equipment {
  khongDungCu,
  taDon,
  taDoi,
  dayKhangLuc,
  gheTap,
  mayTapNguc,
  mayKeoXo,
  mayTapChan,
  xaNgang;

  static const _keys = {
    Equipment.khongDungCu: 'khong_dung_cu',
    Equipment.taDon: 'ta_don',
    Equipment.taDoi: 'ta_doi',
    Equipment.dayKhangLuc: 'day_khang_luc',
    Equipment.gheTap: 'ghe_tap',
    Equipment.mayTapNguc: 'may_tap_nguc',
    Equipment.mayKeoXo: 'may_keo_xo',
    Equipment.mayTapChan: 'may_tap_chan',
    Equipment.xaNgang: 'xa_ngang',
  };

  static const _labels = {
    Equipment.khongDungCu: 'Không dụng cụ',
    Equipment.taDon: 'Tạ đơn',
    Equipment.taDoi: 'Tạ đòn',
    Equipment.dayKhangLuc: 'Dây kháng lực',
    Equipment.gheTap: 'Ghế tập',
    Equipment.mayTapNguc: 'Máy tập ngực',
    Equipment.mayKeoXo: 'Máy kéo xô',
    Equipment.mayTapChan: 'Máy tập chân',
    Equipment.xaNgang: 'Xà ngang',
  };

  String get key => _keys[this]!;
  String get label => _labels[this]!;

  static Equipment? fromKey(String? key) => _keys.entries
      .where((e) => e.value == key)
      .map((e) => e.key)
      .firstOrNull;
}

enum Difficulty {
  beginner,
  intermediate,
  advanced;

  static const _keys = {
    Difficulty.beginner: 'beginner',
    Difficulty.intermediate: 'intermediate',
    Difficulty.advanced: 'advanced',
  };

  static const _labels = {
    Difficulty.beginner: 'Cơ bản',
    Difficulty.intermediate: 'Trung bình',
    Difficulty.advanced: 'Nâng cao',
  };

  String get key => _keys[this]!;
  String get label => _labels[this]!;

  static Difficulty fromKey(String? key) => _keys.entries
      .where((e) => e.value == key)
      .map((e) => e.key)
      .firstOrNull ??
      Difficulty.beginner;
}
