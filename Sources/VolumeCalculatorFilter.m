//
//  VolumeCalculatorFilter.m — plugin entry point: Plugins › ROI Tools › Volume Calculator.
//

#import "VolumeCalculatorFilter.h"
#import "VCWindowController.h"

@implementation VolumeCalculatorFilter

- (void)initPlugin
{
}

- (long)filterImage:(NSString *)menuName
{
    // Let the menu close before the window opens.
    dispatch_async(dispatch_get_main_queue(), ^{ [VCWindowController showFromViewers]; });
    return 0;
}

@end
