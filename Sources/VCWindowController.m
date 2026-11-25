//
//  VCWindowController.m — the Volume Calculator window.
//
//  Port of the OsiriX/Horos "Volume Calculator" plugin (Antoine Rosset, 2008). As in the original:
//  the length ROIs ("Length" tool) on the current image of the open 2D viewers give two
//  diameters, oldest study first; each becomes the volume of a sphere, V = π·d³/6, and the change
//  between them is shown. The values follow the ROIs while they are edited. Added: one ROI per
//  viewer and never the same ROI twice, volumes also in mL, the interval between the two study
//  dates and the volume doubling time, diameters typed by hand, Swap, and Copy Results.
//  The window is built in code (no nib).
//

#import "VCWindowController.h"
#import "VCMath.h"
#include <math.h>
#import <OsiriXAPI/PluginFilter.h>

// IsiX implements -roiList (the ROIs of each image of the current series) but its headers no
// longer declare it; Horos declares it. Declared again here for both.
@interface ViewerController (VCROIList)
- (NSMutableArray *)roiList;
@end

// The notification names of the viewer (Notifications.h), as strings: the same in OsiriX, Horos
// and IsiX, and no symbol to resolve at load time.
static NSString * const VCROIChange   = @"roiChange";
static NSString * const VCRemoveROI   = @"removeROI";
static NSString * const VCCloseViewer = @"CloseViewerNotification";

#pragma mark - One measurement

@interface VCSlot : NSObject
@property (strong) ROI *roi;                 // nil: typed by hand
@property (weak) ViewerController *viewer;
@property (copy) NSString *source;            // patient · series, or "Typed by hand"
@property (strong) NSDate *studyDate;
@property double diameter;                    // mm (or pixels when the image has no pixel spacing)
@property BOOL inPixels;
@end

@implementation VCSlot
- (void)clear
{
    self.roi = nil; self.viewer = nil; self.source = @"—"; self.studyDate = nil;
    self.diameter = 0; self.inPixels = NO;
}
- (void)readROI
{
    if (self.roi == nil) return;
    // -MesureLength: gives centimetres (pixels when the image has no pixel spacing), as in
    // OsiriX and Horos; the window works in millimetres.
    float pixels = 0;
    float cm = [self.roi MesureLength:&pixels];
    self.inPixels = !(cm > 0);
    self.diameter = self.inPixels ? pixels : cm * 10.0;
}
@end

#pragma mark - Helpers

static NSNumberFormatter *VCFormatter(NSUInteger decimals)
{
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    f.numberStyle = NSNumberFormatterDecimalStyle;
    f.locale = [NSLocale currentLocale];
    f.minimumFractionDigits = decimals;
    f.maximumFractionDigits = decimals;
    return f;
}

static NSString *VCNumber(double value, NSUInteger decimals)
{
    return [VCFormatter(decimals) stringFromNumber:@(value)];
}

/// A number typed with the decimal separator of the locale, or with a point or a comma.
static double VCParse(NSString *text)
{
    NSString *t = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (t.length == 0) return 0;
    NSNumberFormatter *f = VCFormatter(0);
    f.maximumFractionDigits = 6;
    f.lenient = YES;
    NSNumber *n = [f numberFromString:t];
    if (n) return n.doubleValue;
    return [[t stringByReplacingOccurrencesOfString:@"," withString:@"."] doubleValue];
}

static NSString *VCDate(NSDate *date)
{
    if (!date) return @"—";
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateStyle = NSDateFormatterMediumStyle;
    f.timeStyle = NSDateFormatterNoStyle;
    return [f stringFromDate:date];
}

static NSDate *VCStudyDate(ViewerController *v)
{
    id study = [v currentStudy];
    id date = [study valueForKey:@"date"];
    return [date isKindOfClass:[NSDate class]] ? date : nil;
}

static NSString *VCSource(ViewerController *v)
{
    id study = [v currentStudy], series = [v currentSeries];
    NSString *patient = [study valueForKey:@"name"];
    NSString *seriesName = [series valueForKey:@"name"];
    NSMutableArray *parts = [NSMutableArray array];
    if ([patient isKindOfClass:[NSString class]] && patient.length) [parts addObject:patient];
    if ([seriesName isKindOfClass:[NSString class]] && seriesName.length) [parts addObject:seriesName];
    return parts.count ? [parts componentsJoinedByString:@" · "] : @"Viewer";
}

/// The length ROIs on the image shown in a viewer, the selected ones first.
static NSArray<ROI *> *VCLengthROIs(ViewerController *v)
{
    NSArray *perImage = [v roiList];
    NSInteger index = (NSInteger)[[v imageView] curImage];
    if (index < 0 || index >= (NSInteger)perImage.count) return @[];
    NSMutableArray *selected = [NSMutableArray array], *others = [NSMutableArray array];
    for (ROI *r in perImage[index]) {
        if (![r isKindOfClass:[ROI class]] || [r type] != tMesure) continue;
        long mode = [r ROImode];
        if (mode == ROI_selected || mode == ROI_selectedModify) [selected addObject:r];
        else [others addObject:r];
    }
    return [selected arrayByAddingObjectsFromArray:others];
}

#pragma mark - Window

@implementation VCWindowController
{
    VCSlot *_slots[2];
    NSTextField *_source[2], *_date[2], *_diameter[2], *_unit[2], *_volume[2];
    NSTextField *_change, *_interval, *_doubling, *_hint;
}

static VCWindowController *VCShared;

+ (void)showFromViewers
{
    if (VCShared == nil) VCShared = [[VCWindowController alloc] init];
    [VCShared reloadFromViewers:nil];
    [VCShared showWindow:nil];
    [VCShared.window makeKeyAndOrderFront:nil];
}

- (instancetype)init
{
    NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 560, 330)
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                backing:NSBackingStoreBuffered defer:YES];
    w.title = @"Volume Calculator";
    w.releasedWhenClosed = NO;
    self = [super initWithWindow:w];
    if (!self) return nil;
    w.delegate = self;
    _slots[0] = [VCSlot new]; [_slots[0] clear];
    _slots[1] = [VCSlot new]; [_slots[1] clear];
    [self buildContent];
    [w center];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(roiChanged:) name:VCROIChange object:nil];
    [nc addObserver:self selector:@selector(roiRemoved:) name:VCRemoveROI object:nil];
    [nc addObserver:self selector:@selector(viewerClosed:) name:VCCloseViewer object:nil];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

static NSTextField *VCLabel(NSString *text, BOOL bold)
{
    NSTextField *t = [NSTextField labelWithString:text];
    if (bold) t.font = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
    t.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [t setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    return t;
}

- (void)buildContent
{
    NSView *content = self.window.contentView;

    for (int i = 0; i < 2; i++) {
        _source[i] = VCLabel(@"—", NO);
        _date[i] = VCLabel(@"—", NO);
        _volume[i] = VCLabel(@"—", YES);
        _unit[i] = VCLabel(@"mm", NO);
        _diameter[i] = [NSTextField textFieldWithString:@""];
        _diameter[i].placeholderString = @"diameter";
        _diameter[i].delegate = self;
        _diameter[i].tag = i;
        _diameter[i].alignment = NSTextAlignmentRight;
        [_diameter[i].widthAnchor constraintEqualToConstant:90].active = YES;
    }
    NSStackView *(^diameterRow)(int) = ^NSStackView *(int i) {
        NSStackView *s = [NSStackView stackViewWithViews:@[self->_diameter[i], self->_unit[i]]];
        s.spacing = 4;
        return s;
    };

    NSGridView *grid = [NSGridView gridViewWithViews:@[
        @[VCLabel(@"", NO),          VCLabel(@"Baseline", YES), VCLabel(@"Follow-up", YES)],
        @[VCLabel(@"Source:", NO),   _source[0],   _source[1]],
        @[VCLabel(@"Study date:", NO), _date[0],   _date[1]],
        @[VCLabel(@"Diameter:", NO), diameterRow(0), diameterRow(1)],
        @[VCLabel(@"Volume:", NO),   _volume[0],   _volume[1]],
    ]];
    grid.rowSpacing = 8;
    grid.columnSpacing = 14;
    [grid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;
    [grid columnAtIndex:1].width = 200;
    [grid columnAtIndex:2].width = 200;

    _change = VCLabel(@"—", YES);
    _interval = VCLabel(@"—", NO);
    _doubling = VCLabel(@"—", NO);
    NSGridView *results = [NSGridView gridViewWithViews:@[
        @[VCLabel(@"Volume change:", NO), _change],
        @[VCLabel(@"Interval:", NO), _interval],
        @[VCLabel(@"Doubling time:", NO), _doubling],
    ]];
    results.rowSpacing = 6;
    results.columnSpacing = 14;
    [results columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;

    _hint = [NSTextField wrappingLabelWithString:@""];
    _hint.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    _hint.textColor = [NSColor secondaryLabelColor];

    NSButton *reload = [NSButton buttonWithTitle:@"Reload from Viewers" target:self action:@selector(reloadFromViewers:)];
    NSButton *swap = [NSButton buttonWithTitle:@"Swap" target:self action:@selector(swap:)];
    NSButton *copy = [NSButton buttonWithTitle:@"Copy Results" target:self action:@selector(copyResults:)];
    NSStackView *buttons = [NSStackView stackViewWithViews:@[reload, swap, copy]];

    NSBox *line = [[NSBox alloc] init];
    line.boxType = NSBoxSeparator;

    NSStackView *main = [NSStackView stackViewWithViews:@[grid, line, results, _hint, buttons]];
    main.orientation = NSUserInterfaceLayoutOrientationVertical;
    main.alignment = NSLayoutAttributeLeading;
    main.spacing = 12;
    main.edgeInsets = NSEdgeInsetsMake(18, 18, 18, 18);
    main.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:main];
    [NSLayoutConstraint activateConstraints:@[
        [main.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [main.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [main.topAnchor constraintEqualToAnchor:content.topAnchor],
        [main.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [line.widthAnchor constraintEqualToAnchor:main.widthAnchor constant:-36],
        [_hint.widthAnchor constraintEqualToAnchor:main.widthAnchor constant:-36],
    ]];
}

#pragma mark Reading the viewers

- (IBAction)reloadFromViewers:(id)sender
{
    NSArray *viewers = [[ViewerController getDisplayed2DViewers] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSDate *da = VCStudyDate(a), *db = VCStudyDate(b);
        if (da && db) return [da compare:db];
        return da ? NSOrderedAscending : (db ? NSOrderedDescending : NSOrderedSame);
    }];

    // One ROI per viewer (the selected one, else the first), oldest study first; if that gives
    // fewer than two, a second length ROI from a viewer already used.
    NSMutableArray<NSArray *> *found = [NSMutableArray array];   // @[roi, viewer]
    for (ViewerController *v in viewers) {
        NSArray *rois = VCLengthROIs(v);
        if (rois.count) [found addObject:@[rois[0], v]];
        if (found.count == 2) break;
    }
    for (ViewerController *v in viewers) {
        if (found.count >= 2) break;
        for (ROI *r in VCLengthROIs(v)) {
            BOOL used = NO;
            for (NSArray *pair in found) if (pair[0] == r) used = YES;
            if (!used) { [found addObject:@[r, v]]; break; }
        }
    }

    for (int i = 0; i < 2; i++) {
        VCSlot *s = _slots[i];
        if (i < (int)found.count) {
            ViewerController *v = found[i][1];
            s.roi = found[i][0];
            s.viewer = v;
            s.source = VCSource(v);
            s.studyDate = VCStudyDate(v);
            [s readROI];
        } else if (s.roi != nil || sender != nil) {
            [s clear];   // keep a typed value when the window is reopened, not on Reload
        }
    }

    if (found.count == 0)
        _hint.stringValue = @"No length ROI found. Draw a line (Length tool) across the lesion on the "
                            @"baseline and on the follow-up study, each in its own viewer, then click Reload "
                            @"— or type the diameters.";
    else if (found.count == 1)
        _hint.stringValue = @"One length ROI found. Draw the other one, or type the follow-up diameter.";
    else
        _hint.stringValue = @"Sphere volume V = π·d³/6. The values follow the ROIs as you edit them.";
    [self refresh];
}

- (void)onMain:(dispatch_block_t)block
{
    if ([NSThread isMainThread]) block(); else dispatch_async(dispatch_get_main_queue(), block);
}

- (void)roiChanged:(NSNotification *)note
{
    id object = note.object;
    [self onMain:^{
        BOOL changed = NO;
        for (int i = 0; i < 2; i++) {
            VCSlot *s = self->_slots[i];
            if (s.roi && (object == nil || object == s.roi)) { [s readROI]; changed = YES; }
        }
        if (changed) [self refresh];
    }];
}

- (void)roiRemoved:(NSNotification *)note
{
    id object = note.object;
    [self onMain:^{
        for (int i = 0; i < 2; i++) {
            VCSlot *s = self->_slots[i];
            if (s.roi && object == s.roi) {
                s.roi = nil;   // keep the last value, now as typed
                s.source = @"ROI deleted — last value kept";
            }
        }
        [self refresh];
    }];
}

- (void)viewerClosed:(NSNotification *)note
{
    id object = note.object;
    [self onMain:^{
        for (int i = 0; i < 2; i++) {
            VCSlot *s = self->_slots[i];
            if (s.roi && (s.viewer == nil || object == s.viewer)) {
                s.roi = nil;
                s.viewer = nil;
                s.source = [s.source stringByAppendingString:@" (viewer closed)"];
            }
        }
        [self refresh];
    }];
}

#pragma mark Editing

- (void)controlTextDidChange:(NSNotification *)note
{
    NSTextField *field = note.object;
    if (field.tag < 0 || field.tag > 1) return;
    VCSlot *s = _slots[field.tag];
    // A typed diameter replaces the ROI's: the ROI is no longer followed.
    if (s.roi) { s.roi = nil; s.viewer = nil; s.source = @"Typed by hand"; }
    else if (!s.studyDate) s.source = @"Typed by hand";
    s.diameter = VCParse(field.stringValue);
    s.inPixels = NO;
    [self refresh:NO];
}

- (IBAction)swap:(id)sender
{
    VCSlot *t = _slots[0]; _slots[0] = _slots[1]; _slots[1] = t;
    [self refresh];
}

#pragma mark Results

- (void)refresh { [self refresh:YES]; }

- (void)refresh:(BOOL)updateFields
{
    double v[2];
    for (int i = 0; i < 2; i++) {
        VCSlot *s = _slots[i];
        _source[i].stringValue = s.source ?: @"—";
        _source[i].toolTip = s.source;
        _date[i].stringValue = VCDate(s.studyDate);
        _unit[i].stringValue = s.inPixels ? @"pixels (no pixel spacing)" : @"mm";
        if (updateFields) _diameter[i].stringValue = s.diameter > 0 ? VCNumber(s.diameter, 1) : @"";
        v[i] = VCSphereVolume(s.diameter);
        if (v[i] <= 0) _volume[i].stringValue = @"—";
        else if (s.inPixels) _volume[i].stringValue = [NSString stringWithFormat:@"%@ pixels³", VCNumber(v[i], 0)];
        else _volume[i].stringValue = [NSString stringWithFormat:@"%@ mm³  (%@ mL)", VCNumber(v[i], 0), VCNumber(v[i] / 1000.0, 2)];
    }

    int ok = 0;
    double pct = VCChangePercent(v[0], v[1], &ok);
    if (ok && _slots[0].inPixels != _slots[1].inPixels) ok = 0;   // mm against pixels: meaningless
    _change.stringValue = ok ? [NSString stringWithFormat:@"%@%@ %%   (×%@)", pct > 0 ? @"+" : @"",
                                VCNumber(pct, 1), VCNumber(v[1] / v[0], 2)] : @"—";

    NSDate *d0 = _slots[0].studyDate, *d1 = _slots[1].studyDate;
    double days = (d0 && d1) ? round([d1 timeIntervalSinceDate:d0] / 86400.0) : 0;
    if (d0 && d1) {
        _interval.stringValue = days < 0
            ? [NSString stringWithFormat:@"%@ days — the follow-up is older than the baseline: click Swap", VCNumber(-days, 0)]
            : [NSString stringWithFormat:@"%@ days", VCNumber(days, 0)];
    } else {
        _interval.stringValue = @"— (needs both study dates)";
    }

    int dok = 0;
    double vdt = ok ? VCDoublingTimeDays(v[0], v[1], days, &dok) : 0;
    if (!dok) _doubling.stringValue = @"—";
    else if (vdt > 0) _doubling.stringValue = [NSString stringWithFormat:@"%@ days (volume doubling time)", VCNumber(vdt, 0)];
    else _doubling.stringValue = [NSString stringWithFormat:@"%@ days (volume halving time)", VCNumber(-vdt, 0)];
}

- (IBAction)copyResults:(id)sender
{
    NSMutableString *text = [NSMutableString stringWithString:@"Volume (sphere, V = π·d³/6)\n"];
    NSArray *names = @[@"Baseline", @"Follow-up"];
    for (int i = 0; i < 2; i++) {
        VCSlot *s = _slots[i];
        if (!(s.diameter > 0)) continue;
        NSString *date = s.studyDate ? [NSString stringWithFormat:@" (%@)", VCDate(s.studyDate)] : @"";
        [text appendFormat:@"%@%@: d = %@ %@, V = %@\n", names[i], date, VCNumber(s.diameter, 1),
                           s.inPixels ? @"pixels" : @"mm", _volume[i].stringValue];
    }
    if (![_change.stringValue isEqualToString:@"—"]) [text appendFormat:@"Change: %@\n", _change.stringValue];
    if (![_doubling.stringValue isEqualToString:@"—"])
        [text appendFormat:@"Interval: %@; %@\n", _interval.stringValue, _doubling.stringValue];
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:text forType:NSPasteboardTypeString];
}

- (void)windowWillClose:(NSNotification *)notification
{
    // Keep nothing alive: the next run starts afresh.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    dispatch_async(dispatch_get_main_queue(), ^{ VCShared = nil; });
}

@end
