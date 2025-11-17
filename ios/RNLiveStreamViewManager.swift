import ApiVideoLiveStream
import CoreGraphics
import Foundation

@objc(RNLiveStreamViewManager)
class RNLiveStreamViewManager: RCTViewManager {
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }

    override func view() -> (RNLiveStreamViewImpl) {
        return RNLiveStreamViewImpl()
    }

    @objc(startStreaming:withRequestId:withStreamKey:withUrl:)
    func startStreaming(_ reactTag: NSNumber, withRequestId requestId: NSNumber, streamKey: String, url: String?) {
        guard let bridge = bridge else {
            print("⚠️ [RNLiveStreamViewManager] Bridge is nil, cannot start streaming")
            return
        }
        
        // Retry mechanism: try up to 5 times with delays to find the view
        var retryCount = 0
        let maxRetries = 5
        
        func tryStartStreaming() {
            print("🔍 [RNLiveStreamViewManager] Attempting to find view with tag: \(reactTag) (attempt \(retryCount + 1)/\(maxRetries))")
            bridge.uiManager.addUIBlock { (_: RCTUIManager?, viewRegistry: [NSNumber: UIView]?) in
                guard let viewRegistry = viewRegistry else {
                    print("⚠️ [RNLiveStreamViewManager] View registry is nil")
                    retryCount += 1
                    if retryCount < maxRetries {
                        let delay = Double(retryCount) * 0.1
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            tryStartStreaming()
                        }
                    }
                    return
                }
                
                print("🔍 [RNLiveStreamViewManager] View registry has \(viewRegistry.count) views")
                if let view = viewRegistry[reactTag] as? RNLiveStreamViewImpl {
                    print("✅ [RNLiveStreamViewManager] View found for tag: \(reactTag), starting stream with requestId: \(requestId)")
                    view.startStreaming(requestId: Int(truncating: requestId), streamKey: streamKey, url: url)
                } else {
                    print("⚠️ [RNLiveStreamViewManager] View not found for tag: \(reactTag)")
                    print("🔍 [RNLiveStreamViewManager] Available tags: \(Array(viewRegistry.keys).map { $0.intValue }.sorted())")
                    retryCount += 1
                    if retryCount < maxRetries {
                        let delay = Double(retryCount) * 0.1 // 100ms, 200ms, 300ms, 400ms
                        print("⚠️ [RNLiveStreamViewManager] Retrying in \(delay)s (attempt \(retryCount)/\(maxRetries))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            tryStartStreaming()
                        }
                    } else {
                        print("❌ [RNLiveStreamViewManager] View not found for tag: \(reactTag) after \(maxRetries) attempts")
                    }
                }
            }
        }
        
        tryStartStreaming()
    }

    @objc(stopStreaming:)
    func stopStreaming(_ reactTag: NSNumber) {
        guard let bridge = bridge else {
            print("⚠️ [RNLiveStreamViewManager] Bridge is nil, cannot stop streaming")
            return
        }
        bridge.uiManager.addUIBlock { (_: RCTUIManager?, viewRegistry: [NSNumber: UIView]?) in
            guard let viewRegistry = viewRegistry,
                  let view = viewRegistry[reactTag] as? RNLiveStreamViewImpl else {
                print("⚠️ [RNLiveStreamViewManager] View not found for tag: \(reactTag)")
                return
            }
            view.stopStreaming()
        }
    }

    @objc(setZoomRatioCommand:withZoomRatio:)
    func setZoomRatioCommand(_ reactTag: NSNumber, zoomRatio: NSNumber) {
        guard let bridge = bridge else {
            print("⚠️ [RNLiveStreamViewManager] Bridge is nil, cannot set zoom ratio")
            return
        }
        bridge.uiManager.addUIBlock { (_: RCTUIManager?, viewRegistry: [NSNumber: UIView]?) in
            guard let viewRegistry = viewRegistry,
                  let view = viewRegistry[reactTag] as? RNLiveStreamViewImpl else {
                print("⚠️ [RNLiveStreamViewManager] View not found for tag: \(reactTag)")
                return
            }
            view.zoomRatio = zoomRatio.floatValue
        }
    }
}
