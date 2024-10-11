//
//  MCSProxyServer.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSProxyServer.h"
#import "NSURLRequest+MCS.h"
#import "MCSLogger.h"
#import "MCSQueue.h"
#import "MCSHeartbeatManager.h"
#import <objc/message.h>
#if __has_include(<KTVCocoaHTTPServer/KTVCocoaHTTPServer.h>)
#import <KTVCocoaHTTPServer/KTVCocoaHTTPServer.h>
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#else
#import "KTVCocoaHTTPServer.h"
#import "GCDAsyncSocket.h"
#endif

@interface MCSHTTPServer : HTTPServer
- (instancetype)initWithProxyServer:(__weak MCSProxyServer *)proxyServer;
@property (nonatomic, weak, readonly, nullable) MCSProxyServer *mcs_server;
@end

@implementation MCSHTTPServer
- (instancetype)initWithProxyServer:(__weak MCSProxyServer *)proxyServer {
    self = [super init];
    if ( self ) {
        _mcs_server = proxyServer;
    }
    return self;
}

- (HTTPConfig *)config {
    return [HTTPConfig.alloc initWithServer:self documentRoot:self->documentRoot queue:mcs_queue()];
}
@end

@interface MCSHTTPConnection : HTTPConnection
- (HTTPMessage *)mcs_request;
- (MCSProxyServer *)mcs_server;
@end
 
@interface MCSHTTPResponse : NSObject<HTTPResponse, MCSProxyTaskDelegate>
- (instancetype)initWithConnection:(MCSHTTPConnection *)connection;
@property (nonatomic, strong) NSURLRequest * request;
@property (nonatomic, strong) id<MCSProxyTask> task;
@property (nonatomic, weak) MCSHTTPConnection *connection;
- (void)prepareForReadingData;
@end

@interface NSURLRequest (MCSHTTPConnectionExtended)
+ (NSMutableURLRequest *)mcs_requestWithMessage:(HTTPMessage *)message;
@end

#pragma mark -

@interface MCSProxyServer ()
@property (nonatomic, strong, nullable) MCSHTTPServer *localServer;
- (id<MCSProxyTask>)taskWithRequest:(NSURLRequest *)request delegate:(id<MCSProxyTaskDelegate>)delegate;
- (BOOL)isHeartBeatRequest:(HTTPMessage *)msg;
@end

@implementation MCSProxyServer {
    MCSHeartbeatManager *mHeartbeatManager;
}
@synthesize serverURL = _serverURL;

- (instancetype)init {
    self = [super init];
    _localServer = [MCSHTTPServer.alloc initWithProxyServer:self];
    [_localServer setConnectionClass:MCSHTTPConnection.class];
    [_localServer setType:@"_http._tcp"];
    
    __weak typeof(self) _self = self;
    mHeartbeatManager = [MCSHeartbeatManager.alloc initWithInterval:10 failureHandler:^(MCSHeartbeatManager * _Nonnull mgr) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        [self stop];
        [self start];
    }];
    return self;
}

- (BOOL)isRunning {
    BOOL notStarted = !_localServer.isRunning || _localServer.listeningPort == 0;
    return !notStarted;
}

- (NSURL *)serverURL {
    @synchronized (self) {
        return _serverURL;
    }
}

- (BOOL)start {
    @synchronized (self) {
        if ( self.isRunning ) return YES;
        
        if ( ![_localServer start:NULL] ) {
            return NO;
        }
        
        _serverURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d", _localServer.listeningPort]];
        mHeartbeatManager.serverURL = _serverURL;
        [_delegate server:self serverURLDidChange:_serverURL];
        [mHeartbeatManager startHeartbeat];
        return YES;
    }
}

- (void)stop {
    [_localServer stop];
    [mHeartbeatManager stopHeartbeat];
}

- (id<MCSProxyTask>)taskWithRequest:(NSURLRequest *)request delegate:(id<MCSProxyTaskDelegate>)delegate {
    return [self.delegate server:self taskWithRequest:request delegate:delegate];
}

- (BOOL)isHeartBeatRequest:(HTTPMessage *)msg {
    return [mHeartbeatManager isHeartBeatRequest:msg];
}
@end

#pragma mark -

@implementation MCSHTTPConnection {
    __weak MCSProxyServer *mServer;
}

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig {
    self = [super initWithAsyncSocket:newSocket configuration:aConfig];
    if ( self ) {
        MCSHTTPConnectionDebugLog(@"\n%@: <%p>.init;\n", NSStringFromClass(self.class), self);
        mServer = ((MCSHTTPServer *)config.server).mcs_server;
    }
    return self;
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path {
    MCSHTTPResponse *response = [MCSHTTPResponse.alloc initWithConnection:self];
    
    MCSHTTPConnectionDebugLog(@"%@: <%p>.response { URL: %@, method: %@, range: %@ };\n", NSStringFromClass(self.class), self, method, response.request.URL, NSStringFromRange(response.request.mcs_range));
    
    [response prepareForReadingData];
    return response;
}

- (HTTPMessage *)mcs_request {
    return request;
}

- (MCSProxyServer *)mcs_server {
    return mServer;
}

- (void)finishResponse {
    [super finishResponse];
    
    MCSHTTPConnectionDebugLog(@"%@: <%p>.finishResponse;\n", NSStringFromClass(self.class), self);
}

- (void)die {
    [super die];
    MCSHTTPConnectionDebugLog(@"%@: <%p>.die;\n", NSStringFromClass(self.class), self);
}

- (void)dealloc {
    MCSHTTPConnectionDebugLog(@"%@: <%p>.dealloc;\n\n", NSStringFromClass(self.class), self);
}

- (void)responseDidAbort:(NSObject<HTTPResponse> *)sender {
    [super responseDidAbort:sender];
    MCSHTTPConnectionDebugLog(@"%@: <%p>.abort;\n", NSStringFromClass(self.class), self);
}
@end

@implementation NSURLRequest (MCSHTTPConnectionExtended)
+ (NSMutableURLRequest *)mcs_requestWithMessage:(HTTPMessage *)message {
    return [self mcs_requestWithURL:message.url headers:message.allHeaderFields];
}
@end

@implementation MCSHTTPResponse {
    BOOL isHeartbeatRequest;
}

- (instancetype)initWithConnection:(MCSHTTPConnection *)connection {
    self = [super init];
    if ( self ) {
        _connection = connection;
        
        MCSProxyServer *server = [connection mcs_server];
        if ( [server isHeartBeatRequest:connection.mcs_request] ) {
            isHeartbeatRequest = YES;
        }
        else {
            _request = [NSURLRequest mcs_requestWithMessage:connection.mcs_request];
            _task = [server taskWithRequest:_request delegate:self];
        }
    }
    return self;
}

- (void)prepareForReadingData {
    [_task prepare];
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    return [_task readDataOfLength:length];
}

- (BOOL)isDone {
    return isHeartbeatRequest || _task.isDone;
}

- (void)connectionDidClose {
    [_task close];
}

- (NSDictionary *)httpHeaders {
    NSMutableDictionary *headers = NSMutableDictionary.dictionary;
    headers[@"Server"] = @"localhost";
    headers[@"Content-Type"] = isHeartbeatRequest ? @"application/octet-stream" : _task.response.contentType;
    headers[@"Accept-Ranges"] = @"bytes";
    headers[@"Connection"] = @"keep-alive";
    return headers;
}

- (BOOL)delayResponseHeaders {
    if ( isHeartbeatRequest ) return NO;
    return _task != nil ? !_task.isPrepared : YES;
}

#pragma mark - mark

- (void)task:(id<MCSProxyTask>)task didReceiveResponse:(id<MCSResponse>)response {
    [_connection responseHasAvailableData:self];
}

- (void)task:(id<MCSProxyTask>)task hasAvailableDataWithLength:(NSUInteger)length {
    [_connection responseHasAvailableData:self];
}

- (void)task:(id<MCSProxyTask>)task didAbortWithError:(nullable NSError *)error {
    [_connection responseDidAbort:self];
    MCSProxyServer *server = [_connection mcs_server];
    [server.delegate server:server performTask:task failure:error];
}

#pragma mark - Chunked
 
- (UInt64)contentLength {
    if ( isHeartbeatRequest ) {
        return 0;
    }
    if ( _task.isPrepared ) {
        NSParameterAssert(_task.response.totalLength != 0);
    }
    return _task.response.totalLength;
}

- (UInt64)offset {
    return (UInt64)_task.offset;
}

- (void)setOffset:(UInt64)offset { }
@end
