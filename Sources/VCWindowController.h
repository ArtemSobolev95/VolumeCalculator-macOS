//
//  VCWindowController.h — the Volume Calculator window.
//

#import <Cocoa/Cocoa.h>

@interface VCWindowController : NSWindowController <NSWindowDelegate, NSTextFieldDelegate>

/// The window, created on first use; later calls reload the diameters from the viewers.
+ (void)showFromViewers;

@end
