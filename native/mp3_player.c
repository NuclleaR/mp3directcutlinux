// Playback for MP3 Direct Cut: one MP3 file at a time. miniaudio drives the sound device
// (ALSA, PulseAudio or PipeWire, loaded at run time), and minimp3's seekable decoder
// supplies the samples, so a seek lands on the exact sample.
//
// minimp3: https://github.com/lieff/minimp3 at commit ea99364f61c14656440e8d77e9c233ccf3124633 (CC0).
// miniaudio: https://github.com/mackron/miniaudio release 0.11.25 (public domain or MIT-0).
#define MINIMP3_IMPLEMENTATION
#define MINIMP3_ONLY_MP3
#include "minimp3_ex.h"

#define MINIAUDIO_IMPLEMENTATION
#define MA_NO_DECODING
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#define MA_NO_RESOURCE_MANAGER
#define MA_NO_NODE_GRAPH
#define MA_NO_ENGINE
#include "miniaudio.h"

#include <stdint.h>
#include <stdlib.h>

#define API __attribute__((visibility("default")))

typedef struct {
  ma_context context;
  ma_device device;
  ma_mutex lock;  // guards everything below; the audio thread holds it while decoding
  mp3dec_ex_t dec;
  int has_file;
  int playing;
  uint64_t position;  // in frames (one sample per channel) from the start
} Player;

static void on_audio(ma_device* device, void* output, const void* input, ma_uint32 frames) {
  (void)input;
  Player* p = (Player*)device->pUserData;
  ma_mutex_lock(&p->lock);
  if (p->has_file && p->playing) {
    size_t wanted = (size_t)frames * p->dec.info.channels;
    size_t got = mp3dec_ex_read(&p->dec, (mp3d_sample_t*)output, wanted);
    p->position += got / p->dec.info.channels;
    // The device buffer arrives zeroed, so a short read leaves silence after the end.
    if (got < wanted) p->playing = 0;
  }
  ma_mutex_unlock(&p->lock);
}

static void close_file(Player* p) {
  if (!p->has_file) return;
  ma_device_uninit(&p->device);  // stops the audio thread before the decoder goes away
  mp3dec_ex_close(&p->dec);
  p->has_file = 0;
  p->playing = 0;
  p->position = 0;
}

// Returns NULL when no sound backend can be set up. [silent] uses miniaudio's null
// backend, which plays in real time without a sound card (for tests).
API Player* mp3_player_create(int32_t silent) {
  Player* p = (Player*)calloc(1, sizeof(Player));
  if (p == NULL) return NULL;
  ma_backend null_backend[] = {ma_backend_null};
  if (ma_context_init(silent ? null_backend : NULL, silent ? 1 : 0, NULL, &p->context) != MA_SUCCESS) {
    free(p);
    return NULL;
  }
  ma_mutex_init(&p->lock);
  return p;
}

// Opens [path] paused at the start. Returns 0, or a negative error code.
API int32_t mp3_player_open(Player* p, const char* path) {
  close_file(p);
  if (mp3dec_ex_open(&p->dec, path, MP3D_SEEK_TO_SAMPLE) != 0) return -1;
  if (p->dec.info.channels <= 0 || p->dec.info.hz <= 0 || p->dec.samples == 0) {
    mp3dec_ex_close(&p->dec);
    return -2;
  }
  ma_device_config config = ma_device_config_init(ma_device_type_playback);
  config.playback.format = ma_format_s16;
  config.playback.channels = (ma_uint32)p->dec.info.channels;
  config.sampleRate = (ma_uint32)p->dec.info.hz;
  config.dataCallback = on_audio;
  config.pUserData = p;
  if (ma_device_init(&p->context, &config, &p->device) != MA_SUCCESS) {
    mp3dec_ex_close(&p->dec);
    return -3;
  }
  p->has_file = 1;
  // The device runs all the time and plays silence while paused, so play starts at once.
  if (ma_device_start(&p->device) != MA_SUCCESS) {
    close_file(p);
    return -4;
  }
  return 0;
}

API void mp3_player_set_playing(Player* p, int32_t playing) {
  ma_mutex_lock(&p->lock);
  p->playing = p->has_file && playing;
  ma_mutex_unlock(&p->lock);
}

API int32_t mp3_player_is_playing(Player* p) {
  ma_mutex_lock(&p->lock);
  int playing = p->playing;
  ma_mutex_unlock(&p->lock);
  return playing;
}

API void mp3_player_seek(Player* p, double seconds) {
  ma_mutex_lock(&p->lock);
  if (p->has_file) {
    uint64_t channels = (uint64_t)p->dec.info.channels;
    uint64_t total = p->dec.samples / channels;
    double frame = seconds * p->dec.info.hz;
    uint64_t target = frame <= 0 ? 0 : frame >= (double)total ? total : (uint64_t)(frame + 0.5);
    mp3dec_ex_seek(&p->dec, target * channels);
    p->position = target;
  }
  ma_mutex_unlock(&p->lock);
}

API double mp3_player_position(Player* p) {
  ma_mutex_lock(&p->lock);
  double t = p->has_file ? (double)p->position / p->dec.info.hz : 0;
  ma_mutex_unlock(&p->lock);
  return t;
}

API void mp3_player_destroy(Player* p) {
  close_file(p);
  ma_mutex_uninit(&p->lock);
  ma_context_uninit(&p->context);
  free(p);
}
