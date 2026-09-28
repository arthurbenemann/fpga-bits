// audio.h -- Audio dropped (no DAC/speaker on this board). Replaces
// Firmware/AUDIO/Audio.h + sounds.h with no-op stubs so chessInterface.c's
// sound calls (move "tuc", checkmate jingle, per-difficulty quip) compile
// and do nothing, rather than editing them out of the ported file.
#ifndef AUDIO_H
#define AUDIO_H

#define playSound(x)   ((void)0)
static inline int isPlaying(void) { return 0; }

enum {
    S_TUC, S_CHECKMATE, S_STALEMATE,
    S_PIECEOFCAKE, S_GETSOME, S_DAMN, S_HOLY,
};

#endif
