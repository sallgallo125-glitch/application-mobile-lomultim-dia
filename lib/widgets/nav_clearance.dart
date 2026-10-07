import 'package:flutter/widgets.dart';

/// Space taken at the bottom by the floating glass navigation bar (the tab
/// pages scroll behind it): add it to the bottom padding of their lists.
double navBarClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;
