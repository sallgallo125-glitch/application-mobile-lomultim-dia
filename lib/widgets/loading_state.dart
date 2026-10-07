import 'package:flutter/material.dart';

import 'shimmer.dart';

export 'shimmer.dart' show SkeletonLayout;

/// Mirrors ../mobile-app/src/components/ui/LoadingState.tsx, rendered as a
/// shimmer skeleton shaped like the page being loaded. [label] is kept for
/// screen readers.
class LoadingState extends StatelessWidget {
  const LoadingState(
      {super.key, this.label = 'Chargement…', this.layout = SkeletonLayout.list});

  final String label;
  final SkeletonLayout layout;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: label,
        liveRegion: true,
        child: ExcludeSemantics(child: PageSkeleton(layout: layout)),
      ),
    );
  }
}
