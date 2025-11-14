package video.api.reactnative.livestream.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter
import video.api.reactnative.livestream.ViewProps

class OnPermissionsDeniedEvent(
  surfaceId: Int,
  viewTag: Int,
  private val permissions: List<String>
) :
  Event<OnPermissionsDeniedEvent>(surfaceId, viewTag) {
  @Deprecated("Use constructor with explicit surfaceId instead.")
  constructor(viewTag: Int, permissions: List<String>) : this(-1, viewTag, permissions)

  private val params = Arguments.createMap().apply {
    putArray("permissions", Arguments.fromList(permissions))
  }

  override fun getEventName() = ViewProps.Events.PERMISSIONS_DENIED.eventName

  @Deprecated("Use receiveEvent(surfaceId, viewTag, eventName, params) instead.")
  override fun dispatch(rctEventEmitter: RCTEventEmitter) {
    rctEventEmitter.receiveEvent(viewTag, eventName, params)
  }
}
