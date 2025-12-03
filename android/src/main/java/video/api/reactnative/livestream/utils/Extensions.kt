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
  
  // Android 8.1: Voice-optimized audio (64k mono 22kHz)
  if (android.os.Build.VERSION.SDK_INT <= android.os.Build.VERSION_CODES.O_MR1) {
    bitrate = 64000      // 64 kbps - clear voice, IVS compatible
    sampleRate = 22050   // 22 kHz - optimal for voice
    stereo = false       // Mono - saves 50% bandwidth + CPU
    android.util.Log.i("LiveStreamView", "🔧 Android 8.1: Optimized audio (64k mono 22kHz)")
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
  
  // Android 8.1 (API 27): Balanced config for weak OMX encoder
  // CRITICAL: Keep 1280x960 to match ApiVideoView preview surface
  // Dimension mismatch causes encoder crashes during streaming
  if (android.os.Build.VERSION.SDK_INT <= android.os.Build.VERSION_CODES.O_MR1) {
    width = 1280   // MUST match preview surface (deviation causes crashes)
    height = 960   
    fps = 25       // 25fps - 17% less CPU than 30fps, smoother than 24fps
    gopDuration = 1.5f  // 1.5s GOP - balance between keyframe frequency and CPU
    // Keep bitrate from React Native (1.5 Mbps - IVS ADVANCED_HD minimum)
    android.util.Log.i("LiveStreamView", "🔧 Android 8.1: Balanced config (1280x960 @25fps, GOP:1.5s)")
  }
  
  return VideoConfig(
    bitrate = bitrate,
    resolution = Size(width, height),
    fps = fps,
    gopDuration = gopDuration
  )
}

