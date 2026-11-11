#import "TBPlayer.h"
#import <unistd.h>
#import "TBStore.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

NSString *const TBPlayerChanged = @"TBPlayerChanged";

// ---- audio engine: ExtAudioFile -> 10-band EQ (biquads) -> NewTimePitch -> RemoteIO ----
typedef struct {
    ExtAudioFileRef file;
    volatile int playing, ended, eq;
    volatile SInt64 pos;
    double fileSR;
    float g;
    float b[10][5];
    float z[10][2][2];
} Ctx;
static Ctx C;
static AUGraph G;
static AudioUnit TPU;
static const float EQF[10] = {32,64,125,250,500,1000,2000,4000,8000,16000};

static OSStatus feed(void *ref, AudioUnitRenderActionFlags *fl, const AudioTimeStamp *ts, UInt32 bus, UInt32 n, AudioBufferList *io) {
    UInt32 got = 0;
    if (C.file && C.playing && !C.ended) {
        UInt32 fr = n;
        for (UInt32 i = 0; i < io->mNumberBuffers; i++) io->mBuffers[i].mDataByteSize = n * 4;
        if (ExtAudioFileRead(C.file, &fr, io) == noErr) got = fr;
        if (got == 0) {
            C.ended = 1;
            dispatch_async(dispatch_get_main_queue(), ^{ [[TBPlayer shared] trackEnded]; });
        }
    }
    for (UInt32 i = 0; i < io->mNumberBuffers; i++) {
        float *p = (float *)io->mBuffers[i].mData;
        if (!p) continue;
        if (got && C.eq) {
            int ch = i & 1;
            for (UInt32 k = 0; k < got; k++) {
                float x = p[k];
                for (int s = 0; s < 10; s++) {
                    float *b = C.b[s];
                    float y = b[0] * x + C.z[s][ch][0];
                    C.z[s][ch][0] = b[1] * x - b[3] * y + C.z[s][ch][1];
                    C.z[s][ch][1] = b[2] * x - b[4] * y;
                    x = y;
                }
                p[k] = x * C.g;
            }
        }
        if (got < n) memset(p + got, 0, (n - got) * 4);
        io->mBuffers[i].mDataByteSize = n * 4;
    }
    C.pos += got;
    return noErr;
}

static AudioStreamBasicDescription FMT(void) {
    AudioStreamBasicDescription f; memset(&f, 0, sizeof f);
    f.mSampleRate = 44100; f.mFormatID = kAudioFormatLinearPCM;
    f.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    f.mBytesPerPacket = 4; f.mFramesPerPacket = 1; f.mBytesPerFrame = 4; f.mChannelsPerFrame = 2; f.mBitsPerChannel = 32;
    return f;
}

@implementation TBPlayer { BOOL _graphReady; NSTimer *_tick; }
@synthesize curId = _curId, playing = _playing;

+ (TBPlayer *)shared { static TBPlayer *p; static dispatch_once_t o; dispatch_once(&o, ^{ p = [TBPlayer new]; C.g = 1; }); return p; }

- (void)startSession {
    AVAudioSession *as = [AVAudioSession sharedInstance];
    [as setCategory:AVAudioSessionCategoryPlayback error:nil];
    [as setActive:YES error:nil];
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        if ([n.userInfo[AVAudioSessionInterruptionTypeKey] intValue] == AVAudioSessionInterruptionTypeBegan) { if (_playing) [self toggle]; }
        else [[AVAudioSession sharedInstance] setActive:YES error:nil];
    }];
    _tick = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
}

- (void)tick {
    if (!_playing) return;
    TBStore *s = [TBStore shared]; s.secs += 1;
    if (((int)s.secs) % 30 == 0) [s save];
}

- (void)setup {
    if (_graphReady) return;
    AudioComponentDescription tp = {kAudioUnitType_FormatConverter, kAudioUnitSubType_NewTimePitch, kAudioUnitManufacturer_Apple, 0, 0};
    AudioComponentDescription ou = {kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple, 0, 0};
    AUNode tpN, ouN; AudioUnit ouU;
    NewAUGraph(&G);
    AUGraphAddNode(G, &tp, &tpN); AUGraphAddNode(G, &ou, &ouN);
    AUGraphOpen(G);
    AUGraphNodeInfo(G, tpN, NULL, &TPU); AUGraphNodeInfo(G, ouN, NULL, &ouU);
    AudioStreamBasicDescription f = FMT();
    AudioUnitSetProperty(TPU, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,  0, &f, sizeof f);
    AudioUnitSetProperty(TPU, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &f, sizeof f);
    AudioUnitSetProperty(ouU, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,  0, &f, sizeof f);
    AURenderCallbackStruct cb = {feed, NULL};
    AUGraphSetNodeInputCallback(G, tpN, 0, &cb);
    AUGraphConnectNodeInput(G, tpN, 0, ouN, 0);
    AUGraphInitialize(G);
    _graphReady = YES;
}

- (void)applyEQ {
    TBStore *s = [TBStore shared]; float mx = 0;
    for (int i = 0; i < 10; i++) {
        float db = [s.eqGains[i] floatValue]; if (db > mx) mx = db;
        double A = pow(10, db / 40.0), w = 2 * M_PI * EQF[i] / 44100.0, al = sin(w) / (2 * 1.2), c = cos(w), a0 = 1 + al / A;
        C.b[i][0] = (1 + al * A) / a0; C.b[i][1] = (-2 * c) / a0; C.b[i][2] = (1 - al * A) / a0;
        C.b[i][3] = (-2 * c) / a0;     C.b[i][4] = (1 - al / A) / a0;
    }
    C.g = pow(10, -mx / 40.0);
    C.eq = s.eqOn;
}

- (void)applyRate {
    if (!_graphReady) return;
    float r = [[[TBStore shared] song:_curId][@"rate"] floatValue]; if (r < .5) r = 1;
    AudioUnitSetParameter(TPU, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, r, 0);
    float cents = [TBStore shared].keepPitch ? 0 : 1200 * log2f(r);
    AudioUnitSetParameter(TPU, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, cents, 0);
}
- (void)setSpeed:(float)r {
    NSMutableDictionary *s = [TBStore shared].songs[_curId]; if (!s) return;
    s[@"rate"] = @(r); [self applyRate]; [[TBStore shared] save];
}

- (void)play:(NSString *)sid inList:(NSArray *)l { self.list = l ?: @[sid]; [self load:sid]; }

- (void)load:(NSString *)sid {
    TBStore *st = [TBStore shared]; NSDictionary *s = [st song:sid]; if (!s) return;
    [self setup];
    C.playing = 0;
    ExtAudioFileRef old = C.file; C.file = NULL;
    if (old) { usleep(30000); ExtAudioFileDispose(old); }
    ExtAudioFileRef f;
    if (ExtAudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:[st path:s]], &f) != noErr) return;
    AudioStreamBasicDescription fmt = FMT(), fd; UInt32 sz = sizeof fd;
    ExtAudioFileSetProperty(f, kExtAudioFileProperty_ClientDataFormat, sizeof fmt, &fmt);
    ExtAudioFileGetProperty(f, kExtAudioFileProperty_FileDataFormat, &sz, &fd);
    C.fileSR = fd.mSampleRate > 0 ? fd.mSampleRate : 44100;
    memset(C.z, 0, sizeof C.z);
    C.pos = 0; C.ended = 0; C.file = f; _curId = sid;
    [self applyRate]; [self applyEQ];
    C.playing = 1; AUGraphStart(G); _playing = YES;
    st.plays[sid] = @([st.plays[sid] intValue] + 1);
    [st.recent removeObject:sid]; [st.recent insertObject:sid atIndex:0];
    while (st.recent.count > 50) [st.recent removeLastObject];
    [st save];
    [self nowPlaying];
    [[NSNotificationCenter defaultCenter] postNotificationName:TBPlayerChanged object:nil];
}

- (void)toggle {
    if (!_curId) return;
    _playing = !_playing; C.playing = _playing;
    if (_playing) AUGraphStart(G); else AUGraphStop(G);
    [self nowPlaying];
    [[NSNotificationCenter defaultCenter] postNotificationName:TBPlayerChanged object:nil];
}

- (void)enqueue:(NSString *)sid atFront:(BOOL)front {
    NSMutableArray *q = [TBStore shared].queue[@"ids"];
    if (front) [q insertObject:sid atIndex:0]; else [q addObject:sid];
    [[TBStore shared] save];
}

- (void)trackEnded { if (_repeat == 2) { [self load:_curId]; return; } [self next]; }

- (void)next {
    NSMutableArray *q = [TBStore shared].queue[@"ids"];
    if (q.count) { NSString *n = q[0]; [q removeObjectAtIndex:0]; [[TBStore shared] save]; [self load:n]; return; }
    NSUInteger i = [_list indexOfObject:_curId]; NSString *n = nil;
    if (_shuffle && _list.count) n = _list[arc4random() % _list.count];
    else if (i != NSNotFound && i + 1 < _list.count) n = _list[i + 1];
    else if (_repeat == 1 && _list.count) n = _list[0];
    if (n) [self load:n];
    else { if (_playing) [self toggle]; [self seek:0]; C.ended = 0; }
}
- (void)prev {
    if ([self position] > 3) { [self seek:0]; return; }
    NSUInteger i = [_list indexOfObject:_curId];
    [self load:(i != NSNotFound && i > 0) ? _list[i - 1] : _curId];
}
- (void)seek:(double)sec {
    if (!C.file) return;
    ExtAudioFileSeek(C.file, (SInt64)(sec * C.fileSR));
    C.pos = (SInt64)(sec * 44100); C.ended = 0;
}
- (double)position { return C.pos / 44100.0; }
- (double)duration { return [[TBStore shared] song:_curId] ? [[[TBStore shared] song:_curId][@"dur"] doubleValue] : 0; }

- (void)nowPlaying {
    NSDictionary *s = [[TBStore shared] song:_curId]; if (!s) return;
    float r = [s[@"rate"] floatValue]; if (r < .5) r = 1;
    MPMediaItemArtwork *aw = [[MPMediaItemArtwork alloc] initWithImage:[[TBStore shared] thumbForSong:s]];
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        s[@"title"], MPMediaItemPropertyTitle, s[@"artist"], MPMediaItemPropertyArtist, s[@"album"], MPMediaItemPropertyAlbumTitle,
        s[@"dur"], MPMediaItemPropertyPlaybackDuration, @([self position]), MPNowPlayingInfoPropertyElapsedPlaybackTime,
        @(_playing ? r : 0), MPNowPlayingInfoPropertyPlaybackRate, aw, MPMediaItemPropertyArtwork, nil];
}
@end
