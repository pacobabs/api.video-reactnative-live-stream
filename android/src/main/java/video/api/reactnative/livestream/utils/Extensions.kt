package video.api.reactnative.livestream.utils

import android.util.Size
import com.facebook.react.bridge.ReadableMap
import video.api.livestream.enums.CameraFacingDirection
import video.api.livestream.models.AudioConfig
import video.api.livestream.models.VideoConfig
import video.api.reactnative.livestream.ViewProps
import java.security.InvalidParameterException

fun String.getCameraFacing(): CameraFacingDirection {
  return when (this) {
    "front" -> CameraFacingDirection.FRONT
    "back" -> CameraFacingDirection.BACK
    else -> {
      throw InvalidParameterException("Unknown camera facing direction $this")
    }
  }
}

fun ReadableMap.toAudioConfig(): AudioConfig {
  var bitrate = this.getInt(ViewProps.BITRATE)
  var sampleRate = this.getInt(ViewProps.SAMPLE_RATE)
  var stereo = this.getBoolean(ViewProps.IS_STEREO)
  
  // Android 8.1: Minimal audio for weak OMX encoder
  if (android.os.Build.VERSION.SDK_INT <= android.os.Build.VERSION_CODES.O_MR1) {
    bitrate = 48000      // 48 kbps - minimal but IVS-compatible
    sampleRate = 22050   // 22 kHz - voice-optimized
    stereo = false       // Mono - saves 50% bandwidth + CPU
    android.util.Log.i("LiveStreamView", "🔧 Android 8.1: Ultra-light audio (48k mono 22kHz)")
  }
  
  return AudioConfig(
    bitrate = bitrate,
    sampleRate = sampleRate,
    stereo = stereo,
    echoCanceler = true,
    noiseSuppressor = true
  )
}

fun ReadableMap.toVideoConfig(): VideoConfig {
  val resolutionMap = this.getMap(ViewProps.RESOLUTION)!!
  var width = resolutionMap.getInt(ViewProps.WIDTH)
  var height = resolutionMap.getInt(ViewProps.HEIGHT)
  var bitrate = this.getInt(ViewProps.BITRATE)
  var fps = this.getInt(ViewProps.FPS)
  var gopDuration = this.getDouble(ViewProps.GOP_DURATION).toFloat()
  
  android.util.Log.i("LiveStreamView", "📹 Received video config - ${width}x${height} @${fps}fps, ${bitrate}bps, GOP:${gopDuration}s")
  
  // Android 8.1 (API 27): Ultra-light for weak OMX encoder
  // CRITICAL: Keep 1280x960 to match ApiVideoView preview surface
  // Dimension mismatch causes encoder crashes during streaming
  if (android.os.Build.VERSION.SDK_INT <= android.os.Build.VERSION_CODES.O_MR1) {
    width = 1280   // MUST match preview surface (deviation causes crashes)
    height = 960   
    fps = 20       // 20fps - 33% less CPU than 30fps, minimal memory
    gopDuration = 3.0f  // 3s GOP - 33% fewer keyframes, minimal memory spikes
    // Keep bitrate from React Native (1.5 Mbps - IVS ADVANCED_HD minimum)
    android.util.Log.i("LiveStreamView", "🔧 Android 8.1: Ultra-light (1280x960 @20fps, GOP:3s)")
  }
  
  return VideoConfig(
    bitrate = bitrate,
    resolution = Size(width, height),
    fps = fps,
    gopDuration = gopDuration
  )
}

