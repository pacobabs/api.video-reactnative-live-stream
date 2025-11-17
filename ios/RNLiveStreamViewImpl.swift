//
//  RNLiveStreamViewImpl.swift
//  api.video-reactnative-live-stream
//

import ApiVideoLiveStream
import AVFoundation
import CoreGraphics
import Foundation

extension String {
    func toCaptureDevicePosition() -> AVCaptureDevice.Position {
        switch self {
        case "back":
            return AVCaptureDevice.Position.back
        case "front":
            return AVCaptureDevice.Position.front
        default:
            return AVCaptureDevice.Position.unspecified
        }
    }
}

extension AVCaptureDevice.Position {
    func toCameraPositionName() -> String {
        switch self {
        case AVCaptureDevice.Position.back:
            return "back"
        case AVCaptureDevice.Position.front:
            return "front"
        default:
            return "unspecified"
        }
    }
}

@objc(RNLiveStreamViewImpl)
public class RNLiveStreamViewImpl: UIView {
    private var liveStream: ApiVideoLiveStream?
    private var isStreaming: Bool = false
    private var initializationError: Error?
    private var isInitializing: Bool = false
    
    // Retry tracking for startStreaming
    private var startStreamingRetryCount: Int = 0
    private let maxStartStreamingRetries: Int = 50  // 5 seconds max (50 * 0.1s)
    private var currentStartStreamingRequestId: Int? = nil
    private var currentStartStreamingKey: String? = nil
    private var currentStartStreamingUrl: String? = nil

    private lazy var zoomGesture: UIPinchGestureRecognizer = .init(target: self, action: #selector(zoom(sender:)))
    private let pinchZoomMultiplier: CGFloat = 2.2

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Delay initialization until view is laid out to ensure proper frame
        // This also helps avoid permission-related crashes
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // Initialize only once when view is laid out
        if liveStream == nil && initializationError == nil && !isInitializing {
            initializeLiveStream()
        }
    }
    
    private func initializeLiveStream() {
        guard !isInitializing else { return }
        isInitializing = true
        
        do {
            let stream = try ApiVideoLiveStream(preview: self, initialAudioConfig: nil, initialVideoConfig: nil, initialCamera: nil)
            stream.delegate = self
            liveStream = stream
            initializationError = nil
            addGestureRecognizer(zoomGesture)
            print("✅ [RNLiveStreamViewImpl] ApiVideoLiveStream initialized successfully")
        } catch {
            // Store error instead of crashing - React Native can handle this gracefully
            initializationError = error
            print("⚠️ [RNLiveStreamViewImpl] Failed to initialize ApiVideoLiveStream: \(error.localizedDescription)")
            // Don't add gesture recognizer if initialization failed
        }
        
        isInitializing = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var videoBitrate: Int {
        get {
            guard let liveStream = liveStream else { return 0 }
            return liveStream.videoBitrate
        }
        set {
            liveStream?.videoBitrate = newValue
        }
    }

    private var audioConfig: AudioConfig {
        get {
            guard let liveStream = liveStream else {
                return AudioConfig(bitrate: 96000)
            }
            return liveStream.audioConfig
        }
        set {
            liveStream?.audioConfig = newValue
        }
    }

    private var videoConfig: VideoConfig {
        get {
            guard let liveStream = liveStream else {
                return VideoConfig(bitrate: 1500000, resolution: CGSize(width: 1920, height: 1080), fps: 30, gopDuration: 1)
            }
            return liveStream.videoConfig
        }
        set {
            liveStream?.videoConfig = newValue
        }
    }

    // Helper function to parse resolution string (e.g., "1080p") or dictionary
    private func parseResolution(_ resolution: Any?) -> CGSize {
        guard let resolution = resolution else {
            return CGSize(width: 1920, height: 1080) // Default to 1080p
        }
        
        // If it's a string like "1080p", "720p", etc.
        if let resolutionString = resolution as? String {
            switch resolutionString.lowercased() {
            case "1080p", "fhd":
                return CGSize(width: 1920, height: 1080)
            case "720p", "hd":
                return CGSize(width: 1280, height: 720)
            case "480p", "sd":
                return CGSize(width: 854, height: 480)
            case "360p":
                return CGSize(width: 640, height: 360)
            default:
                print("⚠️ [RNLiveStreamViewImpl] Unknown resolution string: \(resolutionString), defaulting to 1080p")
                return CGSize(width: 1920, height: 1080)
            }
        }
        
        // If it's a dictionary with width and height
        if let resolutionDict = resolution as? Dictionary<String, Int>,
           let width = resolutionDict["width"],
           let height = resolutionDict["height"] {
            return CGSize(width: width, height: height)
        }
        
        // Fallback to default
        print("⚠️ [RNLiveStreamViewImpl] Invalid resolution format, defaulting to 1080p")
        return CGSize(width: 1920, height: 1080)
    }

    @objc public var audio: NSDictionary = [:] {
        didSet {
            guard liveStream != nil else { return }
            guard let bitrate = audio["bitrate"] as? Int else {
                print("⚠️ [RNLiveStreamViewImpl] Missing or invalid audio bitrate")
                return
            }
            audioConfig = AudioConfig(bitrate: bitrate)
        }
    }

    @objc public var video: NSDictionary = [:] {
        didSet {
            guard liveStream != nil else { return }
            
            guard let bitrate = video["bitrate"] as? Int else {
                print("⚠️ [RNLiveStreamViewImpl] Missing or invalid video bitrate")
                return
            }
            
            guard let fps = video["fps"] as? Float64 else {
                print("⚠️ [RNLiveStreamViewImpl] Missing or invalid video fps")
                return
            }
            
            guard let gopDuration = video["gopDuration"] as? Float64 else {
                print("⚠️ [RNLiveStreamViewImpl] Missing or invalid video gopDuration")
                return
            }
            
            if isStreaming {
                videoBitrate = bitrate
            } else {
                let resolution = parseResolution(video["resolution"])
                videoConfig = VideoConfig(bitrate: bitrate,
                                          resolution: resolution,
                                          fps: fps,
                                          gopDuration: gopDuration)
            }
        }
    }

    @objc public var camera: String {
        get {
            guard let liveStream = liveStream else { return "back" }
            return liveStream.cameraPosition.toCameraPositionName()
        }
        set {
            guard let liveStream = liveStream else { return }
            let value = newValue.toCaptureDevicePosition()
            if value == liveStream.cameraPosition {
                return
            }
            liveStream.cameraPosition = value
        }
    }

    @objc public var isMuted: Bool {
        get {
            guard let liveStream = liveStream else { return false }
            return liveStream.isMuted
        }
        set {
            guard let liveStream = liveStream else { return }
            if newValue == liveStream.isMuted {
                return
            }
            liveStream.isMuted = newValue
        }
    }

    @objc public var zoomRatio: Float {
        get {
            guard let liveStream = liveStream else { return 1.0 }
            return Float(liveStream.zoomRatio)
        }
        set {
            liveStream?.zoomRatio = CGFloat(newValue)
        }
    }

    @objc public var enablePinchedZoom: Bool {
        get {
            return zoomGesture.isEnabled
        }
        set {
            zoomGesture.isEnabled = newValue
        }
    }

    @objc public func startStreaming(requestId: Int, streamKey: String, url: String?) {
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.startStreaming(requestId: requestId, streamKey: streamKey, url: url)
            }
            return
        }
        
        // Store request info for retries
        if currentStartStreamingRequestId != requestId {
            // New request - reset retry counter
            startStreamingRetryCount = 0
            currentStartStreamingRequestId = requestId
            currentStartStreamingKey = streamKey
            currentStartStreamingUrl = url
        }
        
        // If liveStream is not initialized yet, wait for it or initialize now
        if liveStream == nil {
            if initializationError != nil {
                // Already tried and failed
                let errorMessage = initializationError?.localizedDescription ?? "Live stream not initialized. Check camera/microphone permissions."
                onStartStreaming([
                    "requestId": requestId,
                    "result": false,
                    "error": errorMessage,
                ])
                // Reset retry tracking
                startStreamingRetryCount = 0
                currentStartStreamingRequestId = nil
                return
            }
            
            // Check retry limit
            if startStreamingRetryCount >= maxStartStreamingRetries {
                let errorMessage = "Live stream initialization timeout after \(maxStartStreamingRetries * 100)ms. Please try again."
                print("❌ [RNLiveStreamViewImpl] \(errorMessage)")
                onStartStreaming([
                    "requestId": requestId,
                    "result": false,
                    "error": errorMessage,
                ])
                // Reset retry tracking
                startStreamingRetryCount = 0
                currentStartStreamingRequestId = nil
                return
            }
            
            startStreamingRetryCount += 1
            print("⏳ [RNLiveStreamViewImpl] Waiting for liveStream initialization (retry \(startStreamingRetryCount)/\(maxStartStreamingRetries))...")
            
            // If initialization is in progress, wait for it
            if isInitializing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.startStreaming(requestId: requestId, streamKey: streamKey, url: url)
                }
                return
            }
            
            // Try to initialize now if not already in progress
            if frame.width > 0 && frame.height > 0 {
                initializeLiveStream()
                // Wait a bit for initialization to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.startStreaming(requestId: requestId, streamKey: streamKey, url: url)
                }
                return
            } else {
                // Wait a bit for layout
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.startStreaming(requestId: requestId, streamKey: streamKey, url: url)
                }
                return
            }
        }
        
        // Reset retry counter on success
        startStreamingRetryCount = 0
        currentStartStreamingRequestId = nil
        
        guard let liveStream = liveStream else {
            let errorMessage = initializationError?.localizedDescription ?? "Live stream not initialized. Check camera/microphone permissions."
            onStartStreaming([
                "requestId": requestId,
                "result": false,
                "error": errorMessage,
            ])
            return
        }
        
        do {
           print("🎥 [RNLiveStreamViewImpl] Starting stream with key: \(streamKey.prefix(10))... and url: \(url ?? "nil")")
           if let url = url {
               try liveStream.startStreaming(streamKey: streamKey, url: url)
           } else {
               try liveStream.startStreaming(streamKey: streamKey)
           }
           isStreaming = true
           print("✅ [RNLiveStreamViewImpl] Stream started successfully, calling onStartStreaming callback with requestId: \(requestId)")
           onStartStreaming([
               "requestId": requestId,
               "result": true,
           ])
           print("✅ [RNLiveStreamViewImpl] onStartStreaming callback called")
       } catch let LiveStreamError.IllegalArgumentError(message) {
           print("❌ [RNLiveStreamViewImpl] IllegalArgumentError: \(message)")
           self.onStartStreaming([
               "requestId": requestId,
               "result": false,
               "error": message,
           ])
       } catch {
           print("❌ [RNLiveStreamViewImpl] Error starting stream: \(error.localizedDescription)")
           onStartStreaming([
               "requestId": requestId,
               "result": false,
               "error": error.localizedDescription,
           ])
       }
    }

    @objc public func stopStreaming() {
        isStreaming = false
        liveStream?.stopStreaming()
    }

    @objc public func setZoomRatio(zoomRatio: CGFloat) {
        liveStream?.zoomRatio = zoomRatio
    }

    @objc
    private func zoom(sender: UIPinchGestureRecognizer) {
        guard let liveStream = liveStream else { return }
        if sender.state == .changed {
            liveStream.zoomRatio = liveStream.zoomRatio + (sender.scale - 1) * pinchZoomMultiplier
            sender.scale = 1
        }
    }

    @objc public var onConnectionSuccess: (_ dictionnary: [String: Any]) -> Void = { _ in }

    @objc public var onConnectionFailed: (_ dictionnary: [String: Any]) -> Void = { _ in }

    @objc public var onDisconnect: (_ dictionnary: [String: Any]) -> Void = { _ in }

    @objc public var onStartStreaming: (_ dictionnary: [String: Any]) -> Void = { _ in }
    
    @objc override public func removeFromSuperview() {
        super.removeFromSuperview()
        liveStream?.stopPreview()
    }
}

extension RNLiveStreamViewImpl: ApiVideoLiveStreamDelegate {
    /// Called when the connection to the rtmp server is successful
    public func connectionSuccess() {
        // Ensure delegate callbacks are on main thread
        if Thread.isMainThread {
            onConnectionSuccess([:])
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onConnectionSuccess([:])
            }
        }
    }

    /// Called when the connection to the rtmp server failed
    public func connectionFailed(_ code: String) {
        isStreaming = false
        // Ensure delegate callbacks are on main thread
        if Thread.isMainThread {
            onConnectionFailed(["code": code])
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onConnectionFailed(["code": code])
            }
        }
    }

    /// Called when the connection to the rtmp server is closed
    public func disconnection() {
        isStreaming = false
        // Ensure delegate callbacks are on main thread
        if Thread.isMainThread {
            onDisconnect([:])
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onDisconnect([:])
            }
        }
    }

    /// Called if an error happened during the audio configuration
    public func audioError(_ error: Error) {
        print("⚠️ [RNLiveStreamViewImpl] Audio error: \(error.localizedDescription)")
    }

    /// Called if an error happened during the video configuration
    public func videoError(_ error: Error) {
        print("⚠️ [RNLiveStreamViewImpl] Video error: \(error.localizedDescription)")
    }
}
