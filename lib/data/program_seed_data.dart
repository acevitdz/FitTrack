import '../models/program.dart';
import 'training_route_catalog.dart';

/// Reviewed, traceable fallback used until the Firebase catalog is loaded.
///
/// The authored session rows come from
/// `docs/32_lo_trinh_tap_luyen_firebase_v2.md`. Enrollment code always pins one
/// immutable 2-, 3- or 4-day version.
abstract final class ProgramSeedData {
  static const defaultFallbackProgramVersionId =
      TrainingRouteCatalog.defaultProgramVersionId;

  static String defaultFallbackProgramVersionIdFor(int sessionsPerWeek) =>
      'KD-NAM-MOI-NHA-${sessionsPerWeek}D-v1';

  static final List<Program> programs = TrainingRouteCatalog.programs;

  static final List<ProgramVersion> versions = TrainingRouteCatalog.versions;
}
