/// `NetworkStatusModel`: connection type (`wifi | mobile | … | none`), whether
/// the API probe answered, and the derived `online` flag; serialises to the
/// `network.status` wire shape.
///
/// Why it exists: one value type shared by the repository, the bridge and the
/// shell Cubit instead of loose booleans.
/// Status: used — produced by `ConnectivityRepository`.
library;

import 'package:equatable/equatable.dart';

class NetworkStatusModel extends Equatable {
  const NetworkStatusModel({
    required this.connectionType,
    required this.reachable,
  });

  static const unknown = NetworkStatusModel(connectionType: 'none', reachable: false);

  /// `wifi | mobile | ethernet | vpn | other | none`.
  final String connectionType;

  /// The API answered the probe (captive portals fail this, §12).
  final bool reachable;

  bool get online => connectionType != 'none' && reachable;

  Map<String, dynamic> toJson() => {
        'online': online,
        'connectionType': connectionType,
        'reachable': reachable,
      };

  @override
  List<Object?> get props => [connectionType, reachable];
}
