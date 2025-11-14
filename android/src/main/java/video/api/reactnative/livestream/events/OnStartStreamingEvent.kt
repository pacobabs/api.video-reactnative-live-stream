package video.api.reactnative.livestream.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter
import video.api.reactnative.livestream.ViewProps

class OnStartStreamingEvent(
  surfaceId: Int,
  viewTag: Int,
  private val requestId: Int,
  private val result: Boolean,
  private val error: String? = null
) :
  Event<OnStartStreamingEvent>(surfaceId, viewTag) {
  @Deprecated("Use constructor with explicit surfaceId instead.")
  constructor(
    viewTag: Int,
    requestId: Int,
    result: Boolean,
    error: String? = null
  ) : this(-1, viewTag, requestId, result, error)

  private val params = Arguments.createMap().apply {
    putInt("requestId", requestId)
    putBoolean("result", result)
    error?.let { putString("error", it) }
  }

  override fun getEventName() = ViewProps.Events.START_STREAMING.eventName

  @Deprecated("Use receiveEvent(surfaceId, viewTag, eventName, params) instead.")
  override fun dispatch(rctEventEmitter: RCTEventEmitter) {
    rctEventEmitter.receiveEvent(viewTag, eventName, params)
  }
}
