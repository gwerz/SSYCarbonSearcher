#import "AppDelegate.h"
#import "SSYCarbonSearcher.h"

@implementation AppDelegate

- (int)printResults:(NSDictionary*)results {
	int iterationIndex = [[results objectForKey:SSYCarbonSearcherResultsKeyIterationIndex] intValue] ;
	NSArray* paths = [results objectForKey:SSYCarbonSearcherResultsKeyPaths] ;
	NSLog(@"Received callback from iteration index %d with %d paths:", iterationIndex, [paths count]) ;
	NSEnumerator* e = [paths objectEnumerator] ;
	NSString* path ;
	while ((path = [e nextObject])) {
		NSLog(@"%@", path) ;
	}
	
	BOOL isDone = [[results objectForKey:SSYCarbonSearcherResultsKeyIsDone] boolValue] ;
	
	if (isDone) {
		int numberFound = [[results objectForKey:SSYCarbonSearcherResultsKeyNumberFound] intValue] ;
		NSLog(@"***** All done after finding %d paths in %d iterations ***** ", numberFound, iterationIndex+1) ;
		NSLog(@"Quitting.") ;
		[NSApp terminate:self] ;
	}
	else {
		NSLog(@"***** Completed %d iterations ***** But more to come...", iterationIndex+1) ;
	}
	
	return SSYCarbonSearcherContinue ;
	// If you don't want prior results repeated with each iteration,
	// change the above return to SSYCarbonSearcherClearAndContinue
}

+ (void)findPaths {
	[SSYCarbonSearcher catalogPathsForName:@"Resources"
							fullNameSearch:YES
						   findDirectories:YES
								 findFiles:NO
					  maxFindsPerIteration:7
					maxSecondsPerIteration:0.5
							 maxIterations:4
						maxFindsGrandTotal:50
								   verbose:NO
				 printResultsEachIteration:NO
							 syncResults_p:NULL
					   asyncCallbackTarget:[NSApp delegate]
					 asyncCallbackSelector:@selector(printResults:)
									 err_p:NULL] ;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSLog(@">>>[%@ %@]", [self class], NSStringFromSelector(_cmd)) ;
	[AppDelegate findPaths] ;
	NSLog(@"<<<[%@ %@]", [self class], NSStringFromSelector(_cmd)) ;
}

@end
