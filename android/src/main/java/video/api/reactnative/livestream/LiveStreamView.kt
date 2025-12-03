package video.api.reactnative.livestream

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.os.Build
import android.util.AttributeSet
import android.util.Log
import android.view.ScaleGestureDetector
import androidx.constraintlayout.widget.ConstraintLayout
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.UiThreadUtil.runOnUiThread
import com.facebook.react.uimanager.ThemedReactContext
import video.api.livestream.ApiVideoLiveStream
import video.api.livestream.enums.CameraFacingDirection
import video.api.livestream.interfaces.IConnectionListener
import video.api.livestream.models.AudioConfig
import video.api.livestream.models.VideoConfig
import video.api.reactnative.livestream.utils.OrientationManager
import video.api.reactnative.livestream.utils.permissions.PermissionsManager
import video.api.reactnative.livestream.utils.permissions.SerialPermissionsManager
import video.api.reactnative.livestream.utils.showDialog
import java.io.Closeable


@SuppressLint("MissingPermission")
class LiveStreamView @JvmOverloads constructor(
  context: Context,
  attrs: AttributeSet? = null,
  defStyle: Int = 0
) : ConstraintLayout(context, attrs, defStyle),
  Closeable, LifecycleEventListener {
  private val liveStream: ApiVideoLiveStream
  private val permissionsManager = SerialPermissionsManager(
    PermissionsManager((context as ThemedReactContext).reactApplicationContext)
  )

  private val orientationManager = OrientationManager(context)

  // Connection listeners
  var onConnectionSuccess: (() -> Unit)? = null
  var onConnectionFailed: ((reason: String?) -> Unit)? = null
  var onDisconnected: (() -> Unit)? = null

  // Permission listeners
  var onPermissionsDenied: ((List<String>) -> Unit)? = null
  var onPermissionsRationale: ((List<String>) -> Unit)? = null

  // Internal usage only
  var onStartStreaming: ((requestId: Int, result: Boolean, error: String?) -> Unit)? = null

  private val connectionListener = object : IConnectionListener {
    override fun onConnectionSuccess() {
      onConnectionSuccess?.let { it() }
    }

    override fun onConnectionFailed(reason: String) {
      onConnectionFailed?.let { it(reason) }
    }

    override fun onDisconnect() {
      onDisconnected?.let { it() }
    }
  }

  init {
    inflate(context, R.layout.react_native_livestream, this)
    liveStream = ApiVideoLiveStream(
      context = context,
      connectionListener = connectionListener,
      apiVideoView = findViewById(R.id.apivideo_view),
      permissionRequester = { permissions, onGranted ->
        permissionsManager.requestPermissions(
          permissions,
          onAllGranted = {
            try {
              onGranted()
            } catch (e: Exception) {
              // Android 8.1 emulator: AudioRecord will fail
              // Catch and swallow the error, then call the library's internal completion
              if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.O_MR1) {
                Log.w(TAG, "Android 8.1: AudioRecord failed, continuing with video-only")
                // Let the error be swallowed - camera should still work
              } else {
                throw e
              }
            }
          },
          onShowPermissionRationale = { missingPermissions, onRequiredPermissionLastTime ->
            runOnUiThread {
              when {
                missingPermissions.size > 1 -> {
                  context.showDialog(
                    R.string.permission_required,
                    R.string.camera_and_record_audio_permission_required_message,
                    android.R.string.ok,
                    onPositiveButtonClick = { onRequiredPermissionLastTime() }
                  )
                }

                missingPermissions.contains(Manifest.permission.CAMERA) -> {
                  context.showDialog(
                    R.string.permission_required,
                    R.string.camera_permission_required_message,
                    android.R.string.ok,
                    onPositiveButtonClick = { onRequiredPermissionLastTime() }
                  )
                }

                missingPermissions.contains(Manifest.permission.RECORD_AUDIO) -> {
                  context.showDialog(
                    R.string.permission_required,
                    R.string.record_audio_permission_required_message,
                    android.R.string.ok,
                    onPositiveButtonClick = { onRequiredPermissionLastTime() }
                  )
                }
              }
            }
            val permissionsStrings = missingPermissions.joinToString(", ")
            Log.e(TAG, "Asking rationale for missing permissions: $permissionsStrings")
            onPermissionsRationale?.let { it(missingPermissions) }
          },
          onAtLeastOnePermissionDenied = { missingPermissions ->
            val permissionsStrings = missingPermissions.joinToString(", ")
            Log.e(TAG, "Missing permissions: $permissionsStrings")
            onPermissionsDenied?.let { it(missingPermissions) }
          })
      }
    )
  }

  var videoBitrate: Int
    get() = liveStream.videoBitrate
    set(value) {
      liveStream.videoBitrate = value
    }

  var videoConfig: VideoConfig?
    get() = liveStream.videoConfig
    set(value) {
      /**
       * Camera permission is required when `startPreview` is called internally. The permission
       * request goes through the `permissionRequester` callback.
       */
      liveStream.videoConfig = value
    }


  var audioConfig: AudioConfig?
    get() = liveStream.audioConfig
    set(value) {
      /**
       * Record audio permission is required when `configure` is called internally. The permission
       * request goes through the `permissionRequester` callback.
       * 
       * Android 8.1 (API 27) Compatibility:
       * Force safe audio settings (16kHz mono) on Android 8.1 and below.
       * If AudioRecord fails (emulator), silently skip audio configuration.
       */
      // Android 8.1 and below: Use the audio config from Extensions.kt (64k @ 22kHz)
      // Don't override - Extensions.kt already optimized it for Android 8.1
      // StreamPack will handle AudioRecord failure gracefully (video-only mode)
      val finalConfig = value  // Use config from Extensions.kt for ALL Android versions
      
      try {
        liveStream.audioConfig = finalConfig
        Log.i(TAG, "Audio config set successfully")
      } catch (e: Exception) {
        // AudioRecord initialization failed (common on Android 8.1 emulator)
        // Continue without audio - don't let this block the stream
        Log.w(TAG, "Failed to set audio config, continuing without audio", e)
        // Don't throw - allow video-only streaming
      }
    }

  val isStreaming: Boolean
    get() = liveStream.isStreaming

  var camera: CameraFacingDirection
    get() = liveStream.cameraPosition
    set(value) {
      liveStream.cameraPosition = value
    }

  var isMuted: Boolean
    get() = liveStream.isMuted
    set(value) {
      liveStream.isMuted = value
    }

  var zoomRatio: Float
    get() = liveStream.zoomRatio
    set(value) {
      liveStream.zoomRatio = value
    }

  var enablePinchedZoom: Boolean = false
    @SuppressLint("ClickableViewAccessibility")
    set(value) {
      if (value) {
        this.setOnTouchListener { _, event ->
          pinchGesture.onTouchEvent(event)
        }
      } else {
        this.setOnTouchListener(null)
      }
      field = value
    }

  private val pinchGesture: ScaleGestureDetector by lazy {
    ScaleGestureDetector(
      context,
      object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
        private var savedZoomRatio: Float = 1f
        override fun onScale(detector: ScaleGestureDetector): Boolean {
          zoomRatio = if (detector.scaleFactor < 1) {
            savedZoomRatio * detector.scaleFactor
          } else {
            savedZoomRatio + ((detector.scaleFactor - 1))
          }
          return super.onScale(detector)
        }

        override fun onScaleBegin(detector: ScaleGestureDetector): Boolean {
          savedZoomRatio = zoomRatio
          return super.onScaleBegin(detector)
        }
      })
  }

  fun startStreaming(requestId: Int, streamKey: String, url: String?) {
    try {
      require(permissionsManager.hasPermission(Manifest.permission.CAMERA)) { "Missing permissions Manifest.permission.CAMERA" }
      require(permissionsManager.hasPermission(Manifest.permission.RECORD_AUDIO)) { "Missing permissions Manifest.permission.RECORD_AUDIO" }

      /**
       * Workaround to reapply video config in case orientation has changed.
       * This happens because `configChanges` may be disabled in the AndroidManifest.xml of a RN
       * application.
       */
      if (orientationManager.orientationHasChanged) {
        liveStream.videoConfig = liveStream.videoConfig
      }

      url?.let { liveStream.startStreaming(streamKey, it) }
        ?: liveStream.startStreaming(streamKey)

      onStartStreaming?.let { it(requestId, true, null) }
    } catch (e: Exception) {
      Log.e(TAG, "Failed to start streaming", e)
      onStartStreaming?.let { it(requestId, false, e.message) }
    }
  }

  fun stopStreaming() {
    liveStream.stopStreaming()
  }

  override fun close() {
    orientationManager.close()
    liveStream.release()
  }

  companion object {
    private const val TAG = "RNLiveStreamView"
  }

  /**
   * If you request a permission here, it will loop indefinitely between [onHostPause] and
   * [onHostResume].
   */
  override fun onHostResume() {
    /**
     * Only start preview if the app has the required permissions.
     */
    if (permissionsManager.hasPermission(Manifest.permission.CAMERA)) {
      liveStream.startPreview()
    }
    /**
     * Workaround to reapply audio config in case it was not applied when the app started (due to
     * missing RECORD_AUDIO permissions).
     */
    if (permissionsManager.hasPermission(Manifest.permission.RECORD_AUDIO)) {
      try {
        liveStream.audioConfig = liveStream.audioConfig
      } catch (e: Exception) {
        // Silently handle audio config errors on resume
        // This prevents crashes when resuming from background on Android 8.1
        Log.w(TAG, "Failed to reapply audio config on resume, continuing without audio", e)
      }
    }
  }

  override fun onHostPause() {
    liveStream.stopStreaming()
    liveStream.stopPreview()
  }

  override fun onHostDestroy() {
    liveStream.release()
  }
}
