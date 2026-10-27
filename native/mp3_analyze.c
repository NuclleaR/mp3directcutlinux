// Waveform analysis for MP3 Direct Cut: decodes MP3 frames with minimp3 and reports
// per-frame loudness (RMS) and peak levels. Cutting never goes through this code.
//
// minimp3: https://github.com/lieff/minimp3 at commit ea99364f61c14656440e8d77e9c233ccf3124633 (CC0).
#define MINIMP3_IMPLEMENTATION
#define MINIMP3_ONLY_MP3
#include "minimp3.h"

#include <limits.h>
#include <math.h>
#include <stdint.h>

#define EXPORT __attribute__((visibility("default"))) __attribute__((used))

// Decodes the frames at `offsets` in order with one decoder, so the bit reservoir works,
// and writes one RMS value per frame to `rms_out` and the max |sample| per bucket of
// 1/peaks_per_sec seconds to `peaks_out`. A frame that decodes to nothing counts as
// samples_per_frame samples of silence, so time stays aligned with the frame list.
// Returns the number of peak buckets, or -1 on bad arguments.
EXPORT int32_t mp3_analyze(const uint8_t *data, int64_t data_len, const uint32_t *offsets, int32_t frame_count,
                           int32_t sample_rate, int32_t samples_per_frame, int32_t peaks_per_sec, float *rms_out,
                           float *peaks_out, int32_t peaks_cap) {
  if (!data || !offsets || !rms_out || !peaks_out || frame_count < 0 || sample_rate <= 0 || peaks_per_sec <= 0) {
    return -1;
  }
  mp3dec_t dec;
  mp3dec_init(&dec);
  mp3d_sample_t pcm[MINIMP3_MAX_SAMPLES_PER_FRAME];
  for (int32_t i = 0; i < peaks_cap; i++) peaks_out[i] = 0;

  int64_t global = 0;
  for (int32_t k = 0; k < frame_count; k++) {
    int64_t off = offsets[k];
    int samples = 0;
    mp3dec_frame_info_t info = {0};
    if (off < data_len) {
      int64_t rem = data_len - off;
      samples = mp3dec_decode_frame(&dec, data + off, rem > INT_MAX ? INT_MAX : (int)rem, pcm, &info);
    }
    if (samples <= 0) {
      rms_out[k] = 0;
      global += samples_per_frame;
      continue;
    }
    int ch = info.channels > 0 ? info.channels : 1;
    double acc = 0;
    for (int s = 0; s < samples; s++) {
      float peak = 0;
      for (int c = 0; c < ch; c++) {
        float v = pcm[s * ch + c] / 32768.0f;
        acc += (double)v * v;
        if (v < 0) v = -v;
        if (v > peak) peak = v;
      }
      int64_t b = (global + s) * peaks_per_sec / sample_rate;
      if (b < peaks_cap && peak > peaks_out[b]) peaks_out[b] = peak;
    }
    rms_out[k] = (float)sqrt(acc / ((double)samples * ch));
    global += samples;
  }
  int64_t buckets = (global * peaks_per_sec + sample_rate - 1) / sample_rate;
  return (int32_t)(buckets > peaks_cap ? peaks_cap : buckets);
}
