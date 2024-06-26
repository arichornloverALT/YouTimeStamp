#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import "../YouTubeHeader/YTColor.h"
#import "../YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h"
#import "../YouTubeHeader/YTMainAppControlsOverlayView.h"
#import "../YouTubeHeader/YTPlayerViewController.h"

#define TweakKey @"YouTimeStamp"

@interface YTMainAppVideoPlayerOverlayViewController (YouTimeStamp)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTPlayerViewController (YouTimeStamp)
@property (nonatomic, assign) CGFloat currentVideoMediaTime;
@property (nonatomic, assign) NSString *currentVideoID;
- (void)didPressYouTimeStamp;
@end

@interface YTMainAppControlsOverlayView (YouTimeStamp)
@property (retain, nonatomic) YTQTMButton *timestampButton;
@property (nonatomic, assign) YTPlayerViewController *playerViewController;
- (void)didPressYouTimeStamp:(id)arg;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouTimeStamp)
@property (retain, nonatomic) YTQTMButton *timestampButton;
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
- (void)didPressYouTimeStamp:(id)arg;
@end


// For displaying snackbars - @theRealfoxster
@interface YTHUDMessage : NSObject
+ (id)messageWithText:(id)text;
- (void)setAction:(id)action;
@end

@interface GOOHUDMessageAction : NSObject
- (void)setTitle:(NSString *)title;
- (void)setHandler:(void (^)(id))handler;
@end

@interface GOOHUDManagerInternal : NSObject
- (void)showMessageMainThread:(id)message;
+ (id)sharedInstance;
@end

NSBundle *YouTimeStampBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakKey ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakKey]];
    });
    return bundle;
}

static UIImage *timestampImage(NSString *qualityLabel) {
    return [%c(QTMIcon) tintImage:[UIImage imageNamed:[NSString stringWithFormat:@"Timestamp@%@", qualityLabel] inBundle: YouTimeStampBundle() compatibleWithTraitCollection:nil] color:[%c(YTColor) white1]];
}

%group Main
%hook YTPlayerViewController
// New method to copy the URL with the timestamp to the clipboard - @arichornlover
%new
- (void)didPressYouTimeStamp {
    // Get the current time of the video
    CGFloat currentTime = self.currentVideoMediaTime;
    NSInteger timeInterval = (NSInteger)currentTime;

    // Create a link using the video ID and the timestamp
    if (self.currentVideoID) {
        NSString *videoId = [NSString stringWithFormat:@"https://youtu.be/%@", self.currentVideoID];
        NSString *timestampString = [NSString stringWithFormat:@"?t=%.0ld", (long)timeInterval];

        // Create link
        NSString *modifiedURL = [videoId stringByAppendingString:timestampString];
        // Copy the link to clipboard
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:modifiedURL];
        // Show a snackbar to inform the user
        [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDMessage) messageWithText:@"URL copied to clipboard"]];

    } else {
        NSLog(@"No video ID available");
    }
}
%end
%end

/**
  * Adds a timestamp copy button to the top area in the video player overlay
  */
%group Top
%hook YTMainAppControlsOverlayView
%property (retain, nonatomic) YTQTMButton *timestampButton;

// Modify the initializers to add the custom timestamp button
- (id)initWithDelegate:(id)delegate {
    self = %orig;
    self.timestampButton = [self createButton:TweakKey accessibilityLabel:@"Copy Timestamp" selector:@selector(didPressYouTimeStamp:)];
    return self;
}
- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    self.timestampButton = [self createButton:TweakKey accessibilityLabel:@"Copy Timestamp" selector:@selector(didPressYouTimeStamp:)];
    return self;
}

// Modify methods that retrieve a button from an ID to return our custom button
- (YTQTMButton *)button:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? self.timestampButton : %orig;
}
- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? timestampImage(@"3") : %orig;
}

// Custom method to handle the timestamp button press
%new(v@:@)
- (void)didPressYouTimeStamp:(id)arg {
    // Call our custom method in the YTPlayerViewController class - this is 
    // directly accessible in the self.playerViewController property
    YTPlayerViewController *playerViewController = self.playerViewController;
    if (playerViewController) {
        [playerViewController didPressYouTimeStamp];
    }
}

%end
%end

/**
  * Adds a timestamp copy button to the bottom area next to the fullscreen button
  */
%group Bottom
%hook YTInlinePlayerBarContainerView
%property (retain, nonatomic) YTQTMButton *timestampButton;

// Modify the initializer to add the custom timestamp button
- (id)init {
    self = %orig;
    self.timestampButton = [self createButton:TweakKey accessibilityLabel:@"Copy Timestamp" selector:@selector(didPressYouTimeStamp:)];
    return self;
}

// Modify methods that retrieve a button from an ID to return our custom button
- (YTQTMButton *)button:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? self.timestampButton : %orig;
}
- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? timestampImage(@"3") : %orig;
}

// Custom method to handle the timestamp button press
%new(v@:@)
- (void)didPressYouTimeStamp:(id)arg {
    // Navigate to the YTPlayerViewController class from here
    YTInlinePlayerBarController *delegate = self.delegate; // for @property
    YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"]; // for ivars
    YTPlayerViewController *parentViewController = _delegate.parentViewController;
    // Call our custom method in the YTPlayerViewController class
    if (parentViewController) {
        [parentViewController didPressYouTimeStamp];
    }
}

%end
%end

%ctor {
    initYTVideoOverlay(TweakKey);
    %init(Main);
    %init(Top);
    %init(Bottom);
}
