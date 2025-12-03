// This guard prevent the code from being compiled in the old architecture
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNLiveStreamView.h"

#import <react/renderer/components/ApiVideoLiveStreamView/ComponentDescriptors.h>
#import <react/renderer/components/ApiVideoLiveStreamView/EventEmitters.h>
#import <react/renderer/components/ApiVideoLiveStreamView/Props.h>
#import <react/renderer/components/ApiVideoLiveStreamView/RCTComponentViewHelpers.h>

#import <React/RCTAssert.h>
#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>


// MARK: Swift classes in ObjC++
#if __has_include("react-native-livestream/react_native_livestream-Swift.h")
#import "react-native-livestream/react_native_livestream-Swift.h"
#else
#import "react_native_livestream-Swift.h"
#endif

using namespace facebook::react;

@class RNLiveStreamViewImpl;

@interface RNLiveStreamView () <RCTApiVideoLiveStreamViewViewProtocol>

@end

// MARK: Implementation

@implementation RNLiveStreamView {
    RNLiveStreamViewImpl * _view;
    NSMutableArray<NSDictionary *> * _pendingStartStreamingEvents;
}

// MARK: Initializers

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        static const auto defaultProps = std::make_shared<const ApiVideoLiveStreamViewProps>();
        _props = defaultProps;
        
        _pendingStartStreamingEvents = [NSMutableArray array];

        _view = [[RNLiveStreamViewImpl alloc] init];
        
        _view.onConnectionSuccess = [self](NSDictionary *dictionary) {
            if (_eventEmitter) {
                ApiVideoLiveStreamViewEventEmitter::OnConnectionSuccess data = {};
                std::static_pointer_cast<const ApiVideoLiveStreamViewEventEmitter>(_eventEmitter)->onConnectionSuccess(data);
            }
        };
        _view.onConnectionFailed = [self](NSDictionary *dictionary) {
            if (_eventEmitter) {
                ApiVideoLiveStreamViewEventEmitter::OnConnectionFailed data = {
                    .code = std::string([[dictionary valueForKey:@"code"] UTF8String]),
                };
                std::static_pointer_cast<const ApiVideoLiveStreamViewEventEmitter>(_eventEmitter)->onConnectionFailed(data);
            }
        };
        _view.onDisconnect = [self](NSDictionary *dictionary) {
            if (_eventEmitter) {
                ApiVideoLiveStreamViewEventEmitter::OnDisconnect data = {};
                std::static_pointer_cast<const ApiVideoLiveStreamViewEventEmitter>(_eventEmitter)->onDisconnect(data);
            }
        };
        
        _view.onStartStreaming = [self](NSDictionary *dictionary) {
            NSLog(@"🎥 [RNLiveStreamView] onStartStreaming callback received, eventEmitter exists: %@", _eventEmitter ? @"YES" : @"NO");
            if (_eventEmitter) {
                NSString *error = [dictionary valueForKey:@"error"];
                std::string stdError;
                if (error != nil) {
                    stdError = std::string([error UTF8String]);
                }
                NSNumber *requestId = [dictionary valueForKey:@"requestId"];
                NSNumber *result = [dictionary valueForKey:@"result"];
                NSLog(@"🎥 [RNLiveStreamView] Emitting onStartStreaming event - requestId: %@, result: %@, error: %@", requestId, result, error ?: @"nil");
                ApiVideoLiveStreamViewEventEmitter::OnStartStreaming data = {
                    .requestId = [requestId intValue],
                    .result = static_cast<bool>([result boolValue]),
                    .error = stdError,
                };
                std::static_pointer_cast<const ApiVideoLiveStreamViewEventEmitter>(_eventEmitter)->onStartStreaming(data);
                NSLog(@"✅ [RNLiveStreamView] onStartStreaming event emitted successfully");
            } else {
                NSLog(@"❌ [RNLiveStreamView] ERROR: _eventEmitter is nil! Queueing event for later emission.");
                // Queue the event to emit when emitter is ready
                [_pendingStartStreamingEvents addObject:dictionary];
            }
        };
        
        self.contentView = _view;
   }
   return self;
}

// MARK: Props
- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
    const auto &oldViewProps = *std::static_pointer_cast<const ApiVideoLiveStreamViewProps>(_props);
    const auto &newViewProps = *std::static_pointer_cast<const ApiVideoLiveStreamViewProps>(props);

    RNLiveStreamViewImpl *view = (RNLiveStreamViewImpl *)self.contentView;
    
    NSString *newCamera = RCTNSStringFromStringNilIfEmpty(toString(newViewProps.camera));
    if (oldViewProps.camera != newViewProps.camera) {
        [view setCamera:newCamera];
    } else if (view.camera != newCamera) {
        [view setCamera:newCamera];
    }

    NSDictionary *newResolution = @{ @"width" : @(newViewProps.video.resolution.width), @"height" : @(newViewProps.video.resolution.height) };
    NSDictionary *newVideoConfig = @{ @"bitrate" : @(newViewProps.video.bitrate), @"resolution" : newResolution, @"fps" : @(newViewProps.video.fps), @"gopDuration" : @(newViewProps.video.gopDuration)};
    if ((oldViewProps.video.bitrate != newViewProps.video.bitrate) || (oldViewProps.video.fps != newViewProps.video.fps) || (oldViewProps.video.resolution.width != newViewProps.video.resolution.width) || (oldViewProps.video.resolution.height != newViewProps.video.resolution.height) || (oldViewProps.video.gopDuration != newViewProps.video.gopDuration)) {
        [view setVideo:newVideoConfig];
    } else if (view.video != newVideoConfig) {
        [view setVideo:newVideoConfig];
    }
    
    if (oldViewProps.isMuted != newViewProps.isMuted) {
        [view setIsMuted:newViewProps.isMuted];
    } else if (view.isMuted != newViewProps.isMuted) {
        [view setIsMuted:newViewProps.isMuted];
    }
    
    NSString *sampleRate = RCTNSStringFromStringNilIfEmpty(toString(newViewProps.audio.sampleRate));
    NSDictionary *newAudioConfig = @{ @"bitrate" : @(newViewProps.audio.bitrate), @"sampleRate" : @([sampleRate intValue]), @"isStereo" : @(newViewProps.audio.isStereo)};
    if ((oldViewProps.audio.bitrate != newViewProps.audio.bitrate) || (oldViewProps.audio.sampleRate != newViewProps.audio.sampleRate) || (oldViewProps.audio.isStereo != newViewProps.audio.isStereo)) {
        [view setAudio:newAudioConfig];
    } else if (view.audio != newAudioConfig) {
        [view setAudio:newAudioConfig];
    }
    
    if (oldViewProps.zoomRatio != newViewProps.zoomRatio) {
        [view setZoomRatio:newViewProps.zoomRatio];
    } else if (view.zoomRatio != newViewProps.zoomRatio) {
        [view setZoomRatio:newViewProps.zoomRatio];
    }
    
    if (oldViewProps.enablePinchedZoom != newViewProps.enablePinchedZoom) {
        [view setEnablePinchedZoom:newViewProps.enablePinchedZoom];
    } else if (view.enablePinchedZoom != newViewProps.enablePinchedZoom) {
        [view setEnablePinchedZoom:newViewProps.enablePinchedZoom];
    }
    
    [super updateProps:props oldProps:oldProps];
    
    // When props update, event emitter should be ready - emit any queued events
    if (_eventEmitter && _pendingStartStreamingEvents.count > 0) {
        NSLog(@"✅ [RNLiveStreamView] Event emitter ready, emitting %lu queued events", (unsigned long)_pendingStartStreamingEvents.count);
        for (NSDictionary *dictionary in _pendingStartStreamingEvents) {
            NSString *error = [dictionary valueForKey:@"error"];
            std::string stdError;
            if (error != nil) {
                stdError = std::string([error UTF8String]);
            }
            NSNumber *requestId = [dictionary valueForKey:@"requestId"];
            NSNumber *result = [dictionary valueForKey:@"result"];
            ApiVideoLiveStreamViewEventEmitter::OnStartStreaming data = {
                .requestId = [requestId intValue],
                .result = static_cast<bool>([result boolValue]),
                .error = stdError,
            };
            std::static_pointer_cast<const ApiVideoLiveStreamViewEventEmitter>(_eventEmitter)->onStartStreaming(data);
        }
        [_pendingStartStreamingEvents removeAllObjects];
    }
}

- (void)handleCommand:(nonnull const NSString *)commandName args:(nonnull const NSArray *)args {
    RCTApiVideoLiveStreamViewHandleCommand(self, commandName, args);
}

// MARK: RCTComponentViewProtocol

- (void)startStreaming:(NSInteger)requestId streamKey:(NSString *)streamKey url:(NSString *)url
{
    [_view startStreamingWithRequestId:requestId streamKey:streamKey url:url];
}

- (void)stopStreaming
{
    [_view stopStreaming];
}

- (void)setZoomRatioCommand:(float)zoomRatio
{
    [_view setZoomRatioWithZoomRatio:zoomRatio];
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
    return concreteComponentDescriptorProvider<ApiVideoLiveStreamViewComponentDescriptor>();
}

@end

Class<RCTComponentViewProtocol> ApiVideoLiveStreamViewCls(void)
{
    return RNLiveStreamView.class;
}

#endif
