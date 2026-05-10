import 'elite_scroll_physics.dart';

// Re-export Elite physics under legacy names for backward compatibility.
// All existing code that imports PremiumScrollPhysics gets the upgraded
// EliteScrollPhysics automatically — zero migration required.

/// @deprecated Use [EliteScrollPhysics] directly.
/// Kept as type alias for backward compatibility.
typedef PremiumScrollPhysics = EliteScrollPhysics;

/// @deprecated Use [EliteAlwaysScrollPhysics] directly.
typedef PremiumAlwaysScrollPhysics = EliteAlwaysScrollPhysics;

// Legacy reference — identical to the original file, replaced by aliases above.
// This file can be kept empty going forward or used for additional wrappers.
