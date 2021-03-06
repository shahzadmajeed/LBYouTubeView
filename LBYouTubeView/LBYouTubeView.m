//
//  LBYouTubeViewController.m
//  LBYouTubeViewController
//
//  Created by Laurin Brandner on 27.05.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "LBYouTubeView.h"
#import <MediaPlayer/MediaPlayer.h>

@interface LBYouTubeView () <NSURLConnectionDelegate> {
    NSURLConnection* connection;
    NSMutableData* htmlData;
    MPMoviePlayerController* controller;
    
    BOOL shouldAutomaticallyStartPlaying;
}

@property (nonatomic, strong) MPMoviePlayerController* controller;
@property (nonatomic, strong) NSURLConnection* connection;
@property (nonatomic, strong) NSMutableData* htmlData;

@property (nonatomic) BOOL shouldAutomaticallyStartPlaying;

-(void)_setupWithURL:(NSURL*)URL;
-(void)_cleanDownloadUp;

-(NSString*)_userAgent;
-(NSString*)_unescapeString:(NSString*)string;
-(void)_loadVideoWithContentOfURL:(NSURL*)videoURL;

-(void)_didSuccessfullyExtractYouTubeURL:(NSURL*)videoURL;
-(void)_failedExtractingYouTubeURLWithError:(NSError*)error;

@end
@implementation LBYouTubeView

@synthesize connection, htmlData, controller, shouldAutomaticallyStartPlaying, highQuality, delegate;

#pragma mark Initialization

-(id)initWithYouTubeURL:(NSURL *)URL {
    self = [super init];
    if (self) {
        [self _setupWithURL:URL];
    }
    return self;
}

-(id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _setupWithURL:nil];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _setupWithURL:nil];
    }
    return self;
}

-(id)init {
    self = [super init];
    if (self) {
        [self _setupWithURL:nil];
    }
    return self;
}

-(void)_setupWithURL:(NSURL *)URL {
    self.backgroundColor = [UIColor blackColor];
    
    self.controller = nil;
    self.htmlData = [NSMutableData data];
    
    if (URL) {
        [self loadYouTubeURL:URL];
    }
}

#pragma mark -
#pragma mark Memory

-(void)dealloc {
    [self.connection cancel];
}

-(void)_cleanDownloadUp {
    self.htmlData = nil;
    self.connection = nil;
}

#pragma mark -
#pragma mark Private

// Modified answer from StackOverflow http://stackoverflow.com/questions/2099349/using-objective-c-cocoa-to-unescape-unicode-characters-ie-u1234

-(NSString*)_unescapeString:(NSString*)string {
    // tokenize based on unicode escape char
    NSMutableString* tokenizedString = [NSMutableString string];
    NSScanner* scanner = [NSScanner scannerWithString:string];
    while ([scanner isAtEnd] == NO)
    {
        // read up to the first unicode marker
        // if a string has been scanned, it's a token
        // and should be appended to the tokenized string
        NSString* token = @"";
        [scanner scanUpToString:@"\\u" intoString:&token];
        if (token != nil && token.length > 0)
        {
            [tokenizedString appendString:token];
            continue;
        }
        
        // skip two characters to get past the marker
        // check if the range of unicode characters is
        // beyond the end of the string (could be malformed)
        // and if it is, move the scanner to the end
        // and skip this token
        NSUInteger location = [scanner scanLocation];
        NSInteger extra = scanner.string.length - location - 4 - 2;
        if (extra < 0)
        {
            NSRange range = {location, -extra};
            [tokenizedString appendString:[scanner.string substringWithRange:range]];
            [scanner setScanLocation:location - extra];
            continue;
        }
        
        // move the location pas the unicode marker
        // then read in the next 4 characters
        location += 2;
        NSRange range = {location, 4};
        token = [scanner.string substringWithRange:range];
        
        // we don't need non-ascii because it would break the json (only intrested in urls) 
        if (token.intValue) {
            unichar codeValue = (unichar) strtol([token UTF8String], NULL, 16);
            [tokenizedString appendString:[NSString stringWithFormat:@"%C", codeValue]];
        }
        
        // move the scanner past the 4 characters
        // then keep scanning
        location += 4;
        [scanner setScanLocation:location];
    }
    
    NSString* retString = [tokenizedString stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
    retString = [tokenizedString stringByReplacingOccurrencesOfString:@"\\\\\"" withString:@""];
    return [retString stringByReplacingOccurrencesOfString:@"\\" withString:@""];
}

-(void)_loadVideoWithContentOfURL:(NSURL *)videoURL {
    self.controller = [[MPMoviePlayerController alloc] initWithContentURL:videoURL];
    self.controller.view.frame = self.bounds;
    [self.controller prepareToPlay];
    
    [self addSubview:self.controller.view];
    
    if (self.shouldAutomaticallyStartPlaying) {
        [self play];
    }
}

-(NSString*)_userAgent {
    UIDevice* device = [UIDevice currentDevice];
    return [NSString stringWithFormat:@"Mozilla/5.0 (%@; CPU iPhone OS %@ like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Mobile/9B176", device.model, [device.systemVersion stringByReplacingOccurrencesOfString:@"." withString:@"_"]];
}

#pragma mark -
#pragma mark Other Methods

-(void)loadYouTubeURL:(NSURL *)URL {
    if (![URL.host isEqualToString:@"www.youtube.com"]) {
        return;
    }
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:[self _userAgent] forHTTPHeaderField:@"User-Agent"];
    
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    [connection start];
}

-(void)play {
    if (self.controller) {
        [self.controller play];
    }
    else {
        self.shouldAutomaticallyStartPlaying = YES;
    }
}

-(void)stop {
    if (self.controller) {
        [self.controller stop];
    }
    else {
        self.shouldAutomaticallyStartPlaying = NO;
    }
}

#pragma mark
#pragma mark Delegate Calls

-(void)_didSuccessfullyExtractYouTubeURL:(NSURL *)videoURL {
    if ([self.delegate respondsToSelector:@selector(youTubeView:didSuccessfullyExtractYouTubeURL:)]) {
        [self.delegate youTubeView:self didSuccessfullyExtractYouTubeURL:videoURL];
    }
}

-(void)_failedExtractingYouTubeURLWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(youTubeView:failedExtractingYouTubeURLWithError:)]) {
        [self.delegate youTubeView:self failedExtractingYouTubeURLWithError:error];
    }
}

#pragma mark -
#pragma mark NSURLConnectionDelegate

-(void)connection:(NSURLConnection *)__unused connection didReceiveData:(NSData *)data {
    [self.htmlData appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)__unused connection {        
    NSString* html = [[NSString alloc] initWithData:self.htmlData encoding:NSUTF8StringEncoding];

    NSString* JSONStart = @"ls.setItem('PIGGYBACK_DATA', \")]}'";
    NSString* JSON = nil;

    NSScanner* scanner = [NSScanner scannerWithString:html];
    [scanner scanUpToString:JSONStart intoString:nil];
    [scanner scanString:JSONStart intoString:nil];
    [scanner scanUpToString:@"\");" intoString:&JSON];  
    JSON = [self _unescapeString:JSON];
    
    NSError* decodingError = nil;
    NSDictionary* JSONCode = [NSJSONSerialization JSONObjectWithData:[JSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&decodingError];

    if (decodingError) {
        // Failed
        
        [self _failedExtractingYouTubeURLWithError:decodingError];
    }
    else {
        // Success
        
        NSDictionary* video = [[JSONCode objectForKey:@"content"] objectForKey:@"video"];
        NSString* streamURL = nil;
        NSString* streamURLKey = @"stream_url";
        
        if (self.highQuality) {
            streamURL = [video objectForKey:[NSString stringWithFormat:@"hq_%@", streamURLKey]];
            if (!streamURL) {
                streamURL = [video objectForKey:streamURLKey];
            }
        }
        else {
            streamURL = [video objectForKey:streamURLKey];
        }
        
        if (streamURL) {
            NSURL* finalVideoURL = [NSURL URLWithString:streamURL];
            
            [self _didSuccessfullyExtractYouTubeURL:finalVideoURL];
            [self _loadVideoWithContentOfURL:finalVideoURL];
        }
        else {
            [self _failedExtractingYouTubeURLWithError:[NSError errorWithDomain:@"Couldn't find the stream URL." code:1 userInfo:[NSDictionary dictionaryWithObject:JSONCode forKey:@"JSONCode"]]];
        }
    }

    [self _cleanDownloadUp];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {      
    [self _cleanDownloadUp];
    [self _failedExtractingYouTubeURLWithError:error];
}

#pragma mark -

@end
