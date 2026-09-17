package com.purelofi.purelofi

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service requires the host activity to extend AudioServiceActivity so
// the playback service can rebind to the Flutter engine. See docs/SPEC.md.
class MainActivity : AudioServiceActivity()
