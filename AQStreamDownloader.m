/*
 * AQStreamDownloader.m
 * Utilities
 * 
 * Created by Jim Dovey on 5/7/2009.
 * 
 * Copyright (c) 2009 Jim Dovey
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * 
 * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 * 
 * Neither the name of the project's author nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import "AQStreamDownloader.h"
#import "NSFileManager+TempFile.h"

static NSString * const AQDownloadStreamFilePathKey = @"AQDownloadStreamFilePath";
static NSString * const AQDownloadRunLoopMode = @"AQDownloadRunLoopMode";

@implementation AQStreamDownloader

@synthesize outputsToMemory, error;

- (id) initWithInputStream: (NSInputStream *) inputStream writeToMemory: (BOOL) writeToMemory
{
    if ( [super init] == nil )
        return ( nil );
    
    outputsToMemory = writeToMemory;
    input = [inputStream retain];
    [input setDelegate: self];
    
    if ( writeToMemory )
    {
        output = [[NSOutputStream alloc] initToMemory];
    }
    else
    {
        NSString * tempFilePath = [[NSFileManager defaultManager] tempFilePath];
        [[NSFileManager defaultManager] createFileAtPath: tempFilePath
                                                contents: [NSData data]
                                              attributes: nil];
        output = [[NSOutputStream alloc] initToFileAtPath: tempFilePath append: NO];
        outputFileName = [tempFilePath copy];
		usingTempFile = YES;
    }
    
    return ( self );
}

- (id) initWithInputStream: (NSInputStream *) inputStream outputFilePath: (NSString *) filePath
{
	self = [super init];
	if ( self == nil )
		return ( nil );
	
	outputsToMemory = NO;
	input = [inputStream retain];
	[input setDelegate: self];
	
	if ( [[NSFileManager defaultManager] fileExistsAtPath: filePath] == NO )
	{
		if ( [[NSFileManager defaultManager] fileExistsAtPath: [filePath stringByDeletingLastPathComponent]] == NO )
		{
			[[NSFileManager defaultManager] createDirectoryAtPath: [filePath stringByDeletingLastPathComponent]
													   attributes: nil];
		}
		
		NSData * d = [[NSData alloc] init];
		[[NSFileManager defaultManager] createFileAtPath: filePath contents: d attributes: nil];
		[d release];
	}
	
	output = [[NSOutputStream alloc] initToFileAtPath: filePath append: NO];
	outputFileName = [filePath copy];
	usingTempFile = NO;
	
	return ( self );
}

- (void) dealloc
{
    if ( (outputFileName != nil) && (usingTempFile) )
    {
        [[NSFileManager defaultManager] removeItemAtPath: outputFileName error: NULL];
    }
    
	[outputFileName release];
    [input release];
    [output release];
    [error release];
    
    [super dealloc];
}

- (NSData *) downloadedData
{
    if ( outputsToMemory )
        return ( [output propertyForKey: NSStreamDataWrittenToMemoryStreamKey] );
    
    if ( outputFileName == nil )
        return ( nil );
    
    return ( [NSData dataWithContentsOfMappedFile: outputFileName] );
}

- (void) stream: (NSStream *) aStream handleEvent: (NSStreamEvent) eventCode
{
    switch ( eventCode )
    {
        default:
            break;
            
        case NSStreamEventErrorOccurred:
            error = [[aStream streamError] copy];
            [input close];
            [output close];
            complete = YES;
            break;
            
        case NSStreamEventOpenCompleted:
            //[output open];
            break;
            
        case NSStreamEventHasBytesAvailable:
        {
            uint8_t buffer[4096];
            NSInteger num = [input read: buffer maxLength: 4096];
            
            NSInteger numWritten = [output write: buffer maxLength: num];
            if ( numWritten != num )
            {
                NSLog( @"Failed to write %d bytes to output stream; only %d bytes written.", (int)num, (int)numWritten );
            }
            
            break;
        }
            
        case NSStreamEventEndEncountered:
        {
            [input close];
            [output close];
            complete = YES;
            break;
        }
    }
}

- (NSData *) downloadDataSync
{
    if ( [input streamStatus] == NSStreamStatusNotOpen )
        [input open];
    [output open];
    [input scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: AQDownloadRunLoopMode];
    
    while ( complete == NO )
    {
        NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
        [[NSRunLoop currentRunLoop] runMode: AQDownloadRunLoopMode beforeDate: [NSDate distantFuture]];
        [pool drain];
    }
    
    return ( self.downloadedData );
}

@end
