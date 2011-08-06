#include <unistd.h>
#include <sysexits.h>
#import "SSYCarbonSearcher.h"

#define DEFAULT_MAX_SECONDS_PER_ITERATION 5.0
#define DEFAULT_MAX_FINDS_PER_ITERATION 64
#define DEFAULT_MAX_ITERATIONS 1000
#define DEFAULT_MAX_FINDS_GRAND_TOTAL 65536

#define BAD_ARGS 1
#define SEARCH_STRING_TOO_LONG 2

OSErr printResults(NSDictionary* results) {
	NSArray* paths        =  [results objectForKey:SSYCarbonSearcherResultsKeyPaths] ;
	BOOL containerChanged = [[results objectForKey:SSYCarbonSearcherResultsKeyContainerChanged] boolValue];
	int numberFound       = [[results objectForKey:SSYCarbonSearcherResultsKeyNumberFound] intValue] ;
	int err               = [[results objectForKey:SSYCarbonSearcherResultsKeyOSErr] intValue] ;
	BOOL isDone           = [[results objectForKey:SSYCarbonSearcherResultsKeyIsDone] boolValue] ;
	BOOL verbose          = [[results objectForKey:SSYCarbonSearcherResultsKeyVerbose] boolValue] ;
	if (verbose) {
		if (isDone) {
			printf("*** All done.  This is the final result:\n") ;
		}
		else {
			printf("Not done yet.  Here are partial results:\n") ;
		}
		printf("Found %d paths, so far.\n", numberFound) ;
	}
	
	int iP ;
	for (iP=0; iP<[paths count]; iP++) {
		printf("%s\n", [[paths objectAtIndex:iP] UTF8String]) ;
	}
	
	if ((err != noErr) && (err != errFSNoMoreItems)) {
		fprintf(stderr, "Error occurred during search: %d\n", err) ;
	}
	
	if (containerChanged) {
		fprintf(stderr, "Container changed during search, so results may be invalid (but this happens frequently).\n") ;
	}
	else {
		fprintf(stderr, "Container did not change during search, so results are indeed valid.\n") ;
	}
	
	return err ;
}

@interface CallbackCatcherDemo : NSObject {
}

@end

@implementation CallbackCatcherDemo

- (int)processResults:(NSDictionary*)results {
	OSErr err = printResults(results) ;
	
	if ([[results objectForKey:SSYCarbonSearcherResultsKeyIsDone] boolValue]) {
		[self release] ;
		exit(err) ;
	}
	
	return SSYCarbonSearcherContinue ;
	// If you don't want previous results to be repeasted, change
	// the above return to SSYCarbonSearcherClearAndContinue
}

@end



void exitError(int err) {
	switch (err) {
		case BAD_ARGS:
			fprintf(stderr, "Bad arguments\n") ;
		case SEARCH_STRING_TOO_LONG:
			fprintf(stderr, "Maximum search string length is %i bytes\n", MAX_SEARCH_BYTES) ;
		default:
			fprintf(stderr, "Unknown error\n") ;
	}
	fprintf(stderr, "Will exit due to usage error\n") ;
	fprintf(stderr, "Usage is:\nCarbonSearch [-(d|f)aFvp] [-s<maxSecsPerIter>] [-n<maxFindsPerIter>] [-i<maxIterations>] [-N<maxFinds>] nameFrag\n   -a  run search asynchronously\n   -d  find directories\n   -f  find files\n   (Default is to find both directories and files)\n   -F  Full-name search (Default is partial-name search)\n   maxSecsPerIter = maximum number of seconds to search before printing newly-found results.\n      0 to hold printing until completely done (\"one big iteration\").  Default is %f sec.\n   maxFindsPerIter = maximum number of matches to find before printing output.  Default is %i.\n   (Output will be printed when maxSecsPerIter or maxFindsPerIter is reached, whichever comes first.)\n   maxIterations = maximum number iterations, then exit.\n      0 for no limit.  Default is %i.\n   maxFindsGrandTotal = Print results of final iteration and then exit when >= this number of matches has been found or exceeded.\n     Default is %i\n   nameFrag = string, fragment of full pathname, to search for.  Carbon Search is inherently case-INsensitive!\n      Use single quotes, double quotes or backslash-escape if spaces in string.\n      Use backslash escape if double quotes in string.\n   -v verbose, print some debugging info\n   -p print partial results after each iteration\nExample:\n   ./CarbonSearch -d -s6.2 -n10 -i50 -N512 afari.ap\nThis example will find, among other things, up to 512 packages (directories) named \"Safari.app\"\nstopping to print after every 6.2 seconds or 10 finds, whichever comes first.\n", DEFAULT_MAX_SECONDS_PER_ITERATION, DEFAULT_MAX_FINDS_PER_ITERATION, DEFAULT_MAX_ITERATIONS, DEFAULT_MAX_FINDS_GRAND_TOTAL) ;	
	exit(EX_USAGE);
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init] ;
	unsigned int maxFindsPerIteration = DEFAULT_MAX_FINDS_PER_ITERATION ;
	unsigned int maxIterations = DEFAULT_MAX_ITERATIONS ;
	unsigned int maxFindsGrandTotal = DEFAULT_MAX_FINDS_GRAND_TOTAL ;
	// Parse command-line arguments
	BOOL runAsync = NO ;
	BOOL findDirectories = NO ;
	BOOL findFiles = NO ;
	BOOL verbose = NO ;
	BOOL fullNameSearch = NO ;
	BOOL printResultsEachIteration = NO ;
	float maxSecondsPerIteration = DEFAULT_MAX_SECONDS_PER_ITERATION ;

	int ch ;
	while ((ch = getopt(argc, (char**)argv, "adfFvps:n:i:N:")) != -1) {
		switch (ch) {
			case 'a':
				runAsync = YES ;
				break;
			case 'd':
				findDirectories = YES ;
				break;
			case 'f':
				findFiles = YES ;
				break;
			case 'F':
				fullNameSearch = YES ;
				break;
			case 'v':
				verbose = YES ;
				break;
			case 'p':
				printResultsEachIteration = YES ;
				break;
			case 's':
				sscanf(optarg, "%f", &maxSecondsPerIteration) ;
				break;
			case 'n':
				sscanf(optarg, "%d", &maxFindsPerIteration) ;
				break;
			case 'i':
				sscanf(optarg, "%d", &maxIterations) ;
				break;
			case 'N':
				sscanf(optarg, "%d", &maxFindsGrandTotal) ;
				break;
			default:
				exitError(BAD_ARGS);
				break;
		}
	}
	argc -= optind;
	argv += optind;

	// Get required at the end argument
	if (argc < 1) {
		exitError(BAD_ARGS) ;
	}
	char* searchString = (char*)argv[--argc];
	if (strlen(searchString) > MAX_SEARCH_BYTES) {
		exitError(SEARCH_STRING_TOO_LONG) ;
	}

	if (verbose) {
		if (maxSecondsPerIteration != 0)
			printf("Each iteration will search for %f seconds or %d matches, whichever comes first, then print.\n", maxSecondsPerIteration, maxFindsPerIteration) ;
		else
			printf("Each iteration will search until %d matches, then print.\n", maxFindsPerIteration) ;
		
		if (maxIterations != 0)
			printf("Will stop iterating, print final results and exit when:\n   all are found,\n   or after %i iterations\n   or when %i items have been found,\n   whichever comes first.\n", maxIterations, maxFindsGrandTotal) ;
		else
			printf("Will stop iterating, print final results and exit when:\n   all are found,\n   or when %i items have been found,\n   whichever comes first.", maxFindsGrandTotal) ;

		if (findDirectories) {
			printf("Will search for all directories whose name includes fragment \"%s\"\n", searchString) ;
		}
		else if (findFiles) {
			printf("Will search for all files whose name includes fragment \"%s\"\n", searchString) ;
		}
		else {
			printf("Will search for all directories and files whose name includes fragment \"%s\"\n", searchString) ;
		}
		
		if (runAsync) {
			printf("Will search asynchronously using PBCatalogSearchAsync.\n") ;
		}
		else {
			printf("Will search synchronously using PBCatalogSearchSync.\n") ;
		}

		if (fullNameSearch) {
			printf("Will do Full Name search\n") ;
		}
		else {
			printf("Will do Partial Name search\n") ;
		}
	}
	
	NSDictionary* syncResults ;
	id asyncCallbackTarget = nil ;
	SEL asyncCallbackSelector = NULL ;
	OSErr err = noErr ;
	
	if (runAsync) {
		asyncCallbackTarget = [[CallbackCatcherDemo alloc] init] ;
		asyncCallbackSelector = @selector(processResults:) ;
	}
	
	BOOL ok = [SSYCarbonSearcher catalogPathsForName:[NSString stringWithUTF8String:searchString]
									  fullNameSearch:fullNameSearch
									 findDirectories:findDirectories
										   findFiles:findFiles
								maxFindsPerIteration:maxFindsPerIteration
							  maxSecondsPerIteration:maxSecondsPerIteration
									   maxIterations:maxIterations
								  maxFindsGrandTotal:maxFindsGrandTotal
											 verbose:verbose
						   printResultsEachIteration:printResultsEachIteration
									   syncResults_p:&syncResults
								 asyncCallbackTarget:asyncCallbackTarget
							   asyncCallbackSelector:asyncCallbackSelector
											   err_p:&err] ;
		
	if (runAsync) {
		if (ok) {
			[[NSRunLoop currentRunLoop] run] ;
		}
		else {
			printf("Search failed to initiate, OSErr=%d.\n", err) ;
			exit(err) ;
		}
	}
	else {
		if (ok) {
			if (verbose) {
				NSMutableDictionary* syncResultsMutant = [syncResults mutableCopy] ;
				[syncResultsMutant setObject:[NSNumber numberWithBool:YES]
									  forKey:SSYCarbonSearcherResultsKeyVerbose] ;
				syncResults = [[syncResultsMutant copy] autorelease] ;
				[syncResultsMutant release] ;
			}
			printResults(syncResults) ;		
		}
		else {
			printf("Search failed to complete, OSErr=%d.\n", err) ;
			exit(err) ;
		}
	}
		
	[pool release] ;
    return EXIT_SUCCESS ;
}