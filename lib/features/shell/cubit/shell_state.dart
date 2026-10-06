/// `ShellState`: sealed states of the WebView screen — `ShellStarting`,
/// `ShellLoading` (with progress), `ShellReady`, `ShellLoadError` (offline or
/// not). `webViewGeneration` bumps when the WebView must be rebuilt (§5.6).
///
/// Why it exists: sealed states let the view switch exhaustively and never
/// carry nullable or mutable fields (flutter-cubit-architecture).
/// Status: used — emitted by `ShellCubit`, rendered by `ShellScreen`.
library;

import 'package:equatable/equatable.dart';

/// [webViewGeneration] changes when the WebView must be recreated (renderer
/// crash, §5.6); the view keys the WebView on it.
sealed class ShellState extends Equatable {
  const ShellState(this.webViewGeneration);
  final int webViewGeneration;

  @override
  List<Object?> get props => [webViewGeneration];
}

/// Reading app info before the WebView can be built.
final class ShellStarting extends ShellState {
  const ShellStarting() : super(0);
}

final class ShellLoading extends ShellState {
  const ShellLoading(super.webViewGeneration, {this.progress = 0});
  final int progress;

  @override
  List<Object?> get props => [webViewGeneration, progress];
}

final class ShellReady extends ShellState {
  const ShellReady(super.webViewGeneration);
}

/// The main frame failed to load. [offline] picks the "No connection" copy.
final class ShellLoadError extends ShellState {
  const ShellLoadError(super.webViewGeneration, {required this.offline});
  final bool offline;

  @override
  List<Object?> get props => [webViewGeneration, offline];
}
