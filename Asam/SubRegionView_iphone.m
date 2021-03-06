#import "SubRegionView_iphone.h"
#import "MapLayoutGuide.h"
#import "AppDelegate.h"
#import "AsamUtility.h"
#import "AsamFetch.h"
#import "AsamResultViewController_iphone.h"
#import "DSActivityView.h"
#import <MapKit/MapKit.h>
#import "Asam.h"
#import "OfflineMapUtility.h"


@interface SubRegionView_iphone() <MKMapViewDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) IBOutlet MKMapView *mapView;
@property (nonatomic, strong) NSMutableArray *selectedSubRegions;
@property (weak, nonatomic) IBOutlet UIToolbar *toolBar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *resetButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *queryButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *regionsButton;

- (void)filterSubregions;
- (void)queryAsam:(id)sender;
- (void)reset;
- (void)dismissView;
- (void)showActionSheet;
- (void)populateSubregions;
- (void)prepareNavBar;
- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer;

@end

@implementation SubRegionView_iphone

#pragma
#pragma mark - View Life Cycles
- (void)viewDidLoad {
    [super viewDidLoad];
    self.selectedSubRegions = [[NSMutableArray alloc] init];
    [self prepareNavBar];
    [self populateSubregions];
    [self setMapType];
    
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) { // iOS 7+
        self.toolBar.tintColor = [UIColor whiteColor];
    }
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.numberOfTapsRequired = 0;
    lpgr.numberOfTouchesRequired = 1;
    lpgr.minimumPressDuration = 0.1;
    [self.mapView addGestureRecognizer:lpgr];
    
    
}

- (void)viewDidUnload{
    self.mapView = nil;
    self.selectedSubRegions = nil;
    [super viewDidUnload];
}

- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }
    
    CGPoint touchPoint = [gestureRecognizer locationInView:self.mapView];
    CLLocationCoordinate2D touchMapCoordinate = [self.mapView convertPoint:touchPoint toCoordinateFromView:self.mapView];
    MKMapPoint mapPoint = MKMapPointForCoordinate(touchMapCoordinate);
    for (id <MKOverlay> overlay in self.mapView.overlays) {
        if ([overlay isKindOfClass:[MKPolygon class]]) {
            MKPolygon *poly = (MKPolygon*)overlay;
            if ([poly.title isEqualToString:@"ocean"] || [poly.title isEqualToString:@"feature"]) {
                break;
            }
            id view = [self.mapView viewForOverlay:poly];
            if ([view isKindOfClass:[MKPolygonView class]]) {
                MKPolygonView *polyView = (MKPolygonView*) view;
                CGPoint polygonViewPoint = [polyView pointForMapPoint:mapPoint];
                BOOL mapCoordinateIsInPolygon = NO;
                if (polyView.path == nil) { // iOS 7 bug workaround.
                    CGMutablePathRef pathReference = CGPathCreateMutable();
                    MKMapPoint *polygonPoints = poly.points;
                    for (int p = 0; p < poly.pointCount; p++) {
                        MKMapPoint mp = polygonPoints[p];
                        if (p == 0) {
                            CGPathMoveToPoint(pathReference, NULL, mp.x, mp.y);
                        }
                        else {
                            CGPathAddLineToPoint(pathReference, NULL, mp.x, mp.y);
                        }
                    }
                    CGPoint mapPointAsCGP = CGPointMake(mapPoint.x, mapPoint.y);
                    mapCoordinateIsInPolygon = CGPathContainsPoint(pathReference, nil, mapPointAsCGP, NO);
                    CGPathRelease(pathReference);
                }
                else {
                    mapCoordinateIsInPolygon = CGPathContainsPoint(polyView.path, nil, polygonViewPoint, NO);
                }
                if (mapCoordinateIsInPolygon) {
                    if (![self.selectedSubRegions containsObject:poly.title]) {
                        [self.selectedSubRegions addObject:poly.title];
                        polyView.strokeColor = [UIColor orangeColor];
                        polyView.fillColor = [[UIColor greenColor] colorWithAlphaComponent:0.7];
                        polyView.opaque = true;
                        break;
                    }
                    else {
                        [self.selectedSubRegions removeObject:poly.title];
                        polyView.strokeColor=[UIColor orangeColor];
                        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                        NSString *maptype = [defaults stringForKey:@"maptype"];
                        if ([@"Offline" isEqual:maptype]) {
                            polyView.fillColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
                        }
                        else {
                            polyView.fillColor = [[UIColor yellowColor] colorWithAlphaComponent:0.2];
                        }
                        
                        break;
                    }
                }
            }
        }
        
    }
    if (self.selectedSubRegions.count > 0) {
        [self setToolbarButtonsEnabled:YES];
    }
    else {
        [self setToolbarButtonsEnabled:NO];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) setToolbarButtonsEnabled:(BOOL)enabled {
    for (UIBarButtonItem *item in self.toolBar.items) {
        item.enabled = enabled;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma
#pragma mark - Map Views
- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay {

    MKPolygonView *polygonView = [[MKPolygonView alloc] initWithOverlay:overlay];
    
    if ([overlay isKindOfClass:[MKPolygon class]]) {

        if ([overlay.title isEqualToString:@"ocean"]) {
            polygonView.fillColor = [UIColor colorWithRed:127/255.0 green:153/255.0 blue:171/255.0 alpha:0.8];
            polygonView.strokeColor = [UIColor clearColor];
            polygonView.lineWidth = 0.0;
            polygonView.opaque = TRUE;
        }
        else if ([overlay.title isEqualToString:@"feature"]) {
            polygonView.fillColor = [UIColor colorWithRed:221/255.0 green:221/255.0 blue:221/255.0 alpha:0.7];
            polygonView.strokeColor = [UIColor clearColor];
            polygonView.lineWidth = 0.0;
            polygonView.opaque = TRUE;
        }
        else {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSString *maptype = [defaults stringForKey:@"maptype"];
            if ([@"Offline" isEqual:maptype]) {
                polygonView.fillColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
            }
            else {
                polygonView.fillColor = [[UIColor yellowColor] colorWithAlphaComponent:0.2];
            }
            polygonView.lineWidth = 2;
            polygonView.strokeColor = [UIColor orangeColor];
        }
        
		return polygonView;
	}
	return nil;
}

#pragma
#pragma mark - Helper method to populate subregions 
- (void)populateSubregions {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"subregions" ofType:@"csv"];
	NSString *fileContents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
	NSArray *pointStrings = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
	for (int idx = 0; idx < pointStrings.count; idx++) {
		NSString *currentPointString = [pointStrings objectAtIndex:idx];
		NSArray *latLonSubArr = [currentPointString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
        NSString *index = [latLonSubArr objectAtIndex:0];
        NSUInteger c = latLonSubArr.count - 1 ;
        CLLocationCoordinate2D pointsToUse[c / 2];
        for (int i = 0; i < c; i++) {
            if (i == 0) {
                double latt = 0.0;
                double lonn = 0.0;
                for (int j = 0; j < c; j++) {
                    
                    // Build the midpoint.
                    if (!(j % 2)) {
                        latt += [[latLonSubArr objectAtIndex:j + 1] doubleValue];
                    }
                    else {
                        lonn += [[latLonSubArr objectAtIndex:j + 1] doubleValue];
                    }
                }
            }
            if (!(i % 2)) {
                double lat = [[latLonSubArr objectAtIndex:i + 1] doubleValue];
                double lon = [[latLonSubArr objectAtIndex:i + 2] doubleValue];
                pointsToUse[i / 2] = CLLocationCoordinate2DMake(lat,lon);
            }
        }
        MKPolygon *poly=[MKPolygon polygonWithCoordinates:pointsToUse count:(c / 2)];
        poly.title = index;
        [self.mapView addOverlay:poly];
    }
    self.mapView.region = MKCoordinateRegionForMapRect(MKMapRectWorld);
}


- (void)prepareNavBar {
    self.title = @"Subregions";
    [self setToolbarButtonsEnabled:NO];
}

- (IBAction)filterSubregions {
    if (self.selectedSubRegions.count == 0) {
        return;
    }
    NSArray *sortedSubregionIds = [[NSArray alloc] initWithArray:self.selectedSubRegions];
    sortedSubregionIds = [sortedSubregionIds sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSMutableString *subregionIds = [[NSMutableString alloc] init];
    for (int i = 0; i < sortedSubregionIds.count; i++) {
        if (i < sortedSubregionIds.count - 1) {
            [subregionIds appendFormat:@"%@, ", [sortedSubregionIds objectAtIndex:i]];
        }
        else {
            [subregionIds appendString:[sortedSubregionIds objectAtIndex:i]];
        }
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Selected Subregions" message:subregionIds delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
    [alert show];
}

- (void)queryAsam:(id)sender {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] init];
    [context setPersistentStoreCoordinator:[appDelegate persistentStoreCoordinator]];
    
    NSMutableArray *subRegionParams = [NSMutableArray array];
    for (int i = 0; i < self.selectedSubRegions.count; i++) {
        [subRegionParams addObject:[NSPredicate predicateWithFormat:@"geographicalSubregion == %@",[self.selectedSubRegions objectAtIndex:i]]];
    }
    NSString *joinedString = [subRegionParams componentsJoinedByString:@" OR "];
    NSPredicate *subRegionsPredicate = [NSPredicate predicateWithFormat:joinedString];
    NSArray *resultArray = nil;
    if ([sender isEqualToString:@"All"]) {
        resultArray  = [context fetchObjectsForEntityName:@"Asam" withPredicate:subRegionsPredicate];
    }
    else {
        NSString *formattedDays =  [AsamUtility subtractDaysWithParamfromToday:sender];
        NSPredicate *daysPredicate = [NSPredicate predicateWithFormat:@"dateofOccurrence >=%@", [AsamUtility getDateFromString:formattedDays]];
        NSArray *preds = @[daysPredicate, subRegionsPredicate];
        NSPredicate *finalPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:preds];
        resultArray = [context fetchObjectsForEntityName:@"Asam" withPredicate:finalPredicate];
    }
    
    if (resultArray.count == 0) {
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"0 ASAM found" message:@"Try different query." delegate:nil cancelButtonTitle:@"OK"  otherButtonTitles:nil];
        [message show];
        return;
    }
    else {
        AsamResultViewController_iphone *asamResultViewController_iphone = [[AsamResultViewController_iphone alloc] initWithNibName:@"AsamResultViewController_iphone" bundle:nil];
        asamResultViewController_iphone.asamArray = resultArray;
        
        [self.navigationController pushViewController:asamResultViewController_iphone animated:YES];
    }
}

- (IBAction) reset {
    if (self.resetButton.enabled == NO) {
        return;
    }
    
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self.mapView removeOverlays:self.mapView.overlays];
    [self.selectedSubRegions removeAllObjects];
    
    [self setToolbarButtonsEnabled:NO];
    [self populateSubregions];
}

- (void)dismissView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma
#pragma mark - Private methods (UIActionSheet) impl.
- (IBAction)showActionSheet {
    if (self.selectedSubRegions.count == 0) {
        return;
    }
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Select the number of days to query:" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Last 60 days", @"Last 90 days", @"Last 180 days", @"Last 1 Year", @"All", nil];
    [actionSheet showInView:self.view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    dispatch_async(mainQueue, ^{
        [DSBezelActivityView activityViewForView:self.view withLabel:@"Fetching Asam(s)..." width:160];
        dispatch_async(dispatch_get_main_queue(), ^{
            switch(buttonIndex) {
                case 0:
                    [self queryAsam:@"60"];
                    break;
                    
                case 1:
                    [self queryAsam:@"90"];
                    break;
                    
                case 2:
                    [self queryAsam:@"180"];
                    break;
                    
                case 3:
                    [self queryAsam:@"365"];
                    break;
                    
                case 4:
                    [self queryAsam:@"All"];
                    break;
                    
                default:
                    break;
            }
        });
        dispatch_async(mainQueue, ^{
            [DSBezelActivityView removeViewAnimated:YES];
        });
    });
}
- (void)setMapType {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *maptype = [defaults stringForKey:@"maptype"];
        
    //set the maptype
    if ([@"Standard" isEqual:maptype]) {
        _mapView.mapType = MKMapTypeStandard;
    }
    else if ([@"Satellite" isEqual:maptype]) {
        _mapView.mapType = MKMapTypeSatellite;
    }
    else if ([@"Hybrid" isEqual:maptype]) {
        _mapView.mapType = MKMapTypeHybrid;
    }
    else if ([@"Offline" isEqual:maptype]) {
        _mapView.mapType = MKMapTypeStandard;
        [_mapView addOverlays:[OfflineMapUtility getPolygons]];
    }
    else {
        _mapView.mapType = MKMapTypeStandard;
    }
    
}

- (id)bottomLayoutGuide {
    return [[MapLayoutGuide alloc] initWithLength:40];
}


@end
