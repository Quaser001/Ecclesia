import '../../models/user_profile.dart';

/// Applies only what the user *added* on the review screen onto the profile as
/// it is NOW.
///
/// Reading a prescription takes seconds, and the other profile editors stay
/// usable meanwhile. Merging onto the profile captured before the read would
/// silently undo any edit made in that window, so we diff [accepted] against
/// [snapshot] (what the review screen started from) and add that difference to
/// [current].
UserProfile mergePrescriptionAdditions({
  required UserProfile current,
  required UserProfile snapshot,
  required UserProfile accepted,
}) {
  List<String> added(List<String> acc, List<String> snap) =>
      acc.where((x) => !snap.contains(x)).toList();

  return current.copyWith(
    healthConditions: {
      ...current.healthConditions,
      ...added(accepted.healthConditions, snapshot.healthConditions),
    }.toList(),
    allergies: {
      ...current.allergies,
      ...added(accepted.allergies, snapshot.allergies),
    }.toList(),
  );
}
