package video.api.reactnative.livestream.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter
import video.api.reactnative.livestream.ViewProps

class OnConnectionFailedEvent(
  surfaceId: Int,
  private val targetViewTag: Int,
  private val reason: String?
) :
  Event<OnConnectionFailedEvent>(surfaceId, targetViewTag) {
  @Deprecated("Use constructor with explicit surfaceId instead.")
  constructor(viewTag: Int, reason: String?) : this(-1, viewTag, reason)

  private val params = Arguments.createMap().apply {
    putString("code", reason)
  }

  override fun getEventName() = ViewProps.Events.CONNECTION_FAILED.eventName

  @Deprecated("Use receiveEvent(surfaceId, viewTag, eventName, params) instead.")
  override fun dispatch(rctEventEmitter: RCTEventEmitter) {
    rctEventEmitter.receiveEvent(targetViewTag, eventName, params)
  }
}
