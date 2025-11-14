package video.api.reactnative.livestream.events

import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter
import video.api.reactnative.livestream.ViewProps

class OnDisconnectEvent(
  surfaceId: Int,
  private val targetViewTag: Int
) :
  Event<OnDisconnectEvent>(surfaceId, targetViewTag) {
  @Deprecated("Use constructor with explicit surfaceId instead.")
  constructor(viewTag: Int) : this(-1, viewTag)

  override fun getEventName() = ViewProps.Events.DISCONNECTED.eventName

  @Deprecated("Use receiveEvent(surfaceId, viewTag, eventName, params) instead.")
  override fun dispatch(rctEventEmitter: RCTEventEmitter) {
    rctEventEmitter.receiveEvent(targetViewTag, eventName, null)
  }
}
