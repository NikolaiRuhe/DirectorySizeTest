#import "ViewController.h"
#import "NRFileManager.h"


@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextView *textView;

@end


@implementation ViewController

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[self testInBackground];
	});
}

- (void)testInBackground
{
	NSInteger fileCount = 100;

	[self testMethod:@"folderSize" fileCount:fileCount withBlock:^long long(NSString *folderPath){
		return [self folderSize:folderPath];
	}];

	[self testMethod:@"allocatedSize" fileCount:fileCount withBlock:^long long(NSString *folderPath){
		return [self allocatedSize:folderPath];
	}];

	fileCount = 1000;

	[self testMethod:@"folderSize" fileCount:fileCount withBlock:^long long(NSString *folderPath){
		return [self folderSize:folderPath];
	}];

	[self testMethod:@"allocatedSize" fileCount:fileCount withBlock:^long long(NSString *folderPath){
		return [self allocatedSize:folderPath];
	}];
}

static void createTestDirectoryAtPath(NSString *directoryPath, NSInteger fileCount)
{
	[[NSFileManager defaultManager] createDirectoryAtPath:directoryPath
							  withIntermediateDirectories:YES
											   attributes:nil
													error:NULL];
	NSMutableData *data = [NSMutableData data];
	NSData *someBytes = [NSData dataWithBytes:(uint8_t[8]){ 1, 2, 4, 5, 6, 7, 8 } length:8];

	for (NSInteger i = 0; i < fileCount; ++i) {
		NSString *name = [NSString stringWithFormat:@"testfile_%04ld", (long)i];
		NSString *path = [directoryPath stringByAppendingPathComponent:name];
		[data writeToFile:path atomically:NO];
		[data appendData:someBytes];
	}
}

- (unsigned long long)folderSize:(NSString *)folderPath
{
	NSArray *filesArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:folderPath error:nil];
	NSEnumerator *filesEnumerator = [filesArray objectEnumerator];
	NSString *fileName;
	unsigned long long int fileSize = 0;

	while ((fileName = [filesEnumerator nextObject])) {
		NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[folderPath stringByAppendingPathComponent:fileName] error:nil];
		fileSize += [fileDictionary fileSize];
	}

	return fileSize;
}

- (unsigned long long)allocatedSize:(NSString *)folderPath
{
	unsigned long long allocatedSize;
	[[NSFileManager defaultManager] nr_getAllocatedSize:&allocatedSize
									   ofDirectoryAtURL:[NSURL fileURLWithPath:folderPath]
												  error:NULL];
	return allocatedSize;
}

static long long fileSystemFreeSize(NSString *path)
{
	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:NULL];
	return [attributes[NSFileSystemFreeSize] unsignedLongLongValue];
}

- (void)log:(NSString *)message
{
	NSLog(@"%@", message);
	dispatch_async(dispatch_get_main_queue(), ^{
		self.textView.text = [self.textView.text stringByAppendingFormat:@"%@\n", message];
	});
}

- (void)testMethod:(NSString *)testMethod fileCount:(NSInteger)fileCount withBlock:(long long(^)(NSString *folderPath))block
{
	[self log:[NSString stringWithFormat:@"\nTest \"%@\"", testMethod]];

	NSString *cachesDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
	NSString *testDirectory = [cachesDirectory stringByAppendingPathComponent:@"Test"];
	[self log:[NSString stringWithFormat:@"    preparing %ld test files...", fileCount]];

	createTestDirectoryAtPath(testDirectory, fileCount / 2);
	createTestDirectoryAtPath([testDirectory stringByAppendingPathComponent:@"SubDirectory"], fileCount / 2);

	[self log:[NSString stringWithFormat:@"    test start..."]];

	CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
	unsigned long long testSize = block(testDirectory);
	CFAbsoluteTime duration = CFAbsoluteTimeGetCurrent() - startTime;

	[self log:[NSString stringWithFormat:@"    test done"]];

	NSByteCountFormatter *sizeFormatter = [[NSByteCountFormatter alloc] init];
	sizeFormatter.includesActualByteCount = YES;

	[self log:[NSString stringWithFormat:@"    size: %@", [sizeFormatter stringFromByteCount:testSize]]];
	[self log:[NSString stringWithFormat:@"    time: %.3f s", duration]];

	[self log:[NSString stringWithFormat:@"    cleaning up..."]];

	long long availableSizeBefore = fileSystemFreeSize(cachesDirectory);
	[[NSFileManager defaultManager] removeItemAtPath:testDirectory error:NULL];
	long long availableSizeAfter = fileSystemFreeSize(cachesDirectory);

	[self log:[NSString stringWithFormat:@"    actual bytes: %@", [sizeFormatter stringFromByteCount:availableSizeAfter - availableSizeBefore]]];
}

@end
