#import "TBPlayer.h"
#import "TBStore.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <libkern/OSAtomic.h>
#import <pthread.h>
#import <unistd.h>

NSString *const TBPlayerChanged = @"TBPlayerChanged";

// Engine: [decoder thread] -> ring buffer -> EQ -> (NewTimePitch only when speed != 1) -> RemoteIO
#define RING 131072
typedef struct {
    ExtAudioFileRef file;
    volatile int playing, ended, eof, eq, useTP;
    volatile SInt64 pos, wr, rd;
    double fileSR;
    float g;
    float b[10][5];
    float z[10][2][2];
} Ctx;
static Ctx C;
static void TBLog(NSString *m) {
    NSString *p = [TBRoot() stringByAppendingPathComponent:@".data/log.txt"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:p]) [@"" writeToFile:p atomically:NO encoding:NSUTF8StringEncoding error:nil];
    NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:p]; if (!h) return;
    [h seekToEndOfFile]; [h writeData:[[m stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]]; [h closeFile];
}
static float RL[RING], RR[RING], TMP[2][4096];
static AudioUnit OUTU, TPU;
static pthread_mutex_t M = PTHREAD_MUTEX_INITIALIZER;
static const float EQF[10] = {32,64,125,250,500,1000,2000,4000,8000,16000};

static UInt32 fill(AudioBufferList *io, UInt32 n) {
    float *L = (float *)io->mBuffers[0].mData;
    float *R = io->mNumberBuffers > 1 ? (float *)io->mBuffers[1].mData : L;
    SInt64 rd = C.rd, avail = C.wr - rd;
    UInt32 k = avail <= 0 ? 0 : (avail > (SInt64)n ? n : (UInt32)avail);
    for (UInt32 i = 0; i < k; i++) { UInt32 ix = (UInt32)((rd + i) & (RING - 1)); L[i] = RL[ix]; R[i] = RR[ix]; }
    OSMemoryBarrier();
    C.rd = rd + k;
    if (k && C.eq) {
        for (int ch = 0; ch < 2; ch++) {
            float *p = ch ? R : L;
            for (UInt32 i = 0; i < k; i++) {
                float x = p[i];
                for (int s = 0; s < 10; s++) {
                    float *b = C.b[s];
                    float y = b[0] * x + C.z[s][ch][0];
                    C.z[s][ch][0] = b[1] * x - b[3] * y + C.z[s][ch][1];
                    C.z[s][ch][1] = b[2] * x - b[4] * y;
                    x = y;
                }
                x *= C.g;
                p[i] = x > 1 ? 1 : (x < -1 ? -1 : x);
            }
        }
    }
    if (k < n) {
        memset(L + k, 0, (n - k) * 4); if (R != L) memset(R + k, 0, (n - k) * 4);
        if (k == 0 && C.eof && !C.ended) { C.ended = 1; dispatch_async(dispatch_get_main_queue(), ^{ [[TBPlayer shared] trackEnded]; }); }
    }
    C.pos += k;
    for (UInt32 i = 0; i < io->mNumberBuffers; i++) io->mBuffers[i].mDataByteSize = n * 4;
    return k;
}
static void silence(AudioBufferList *io) { for (UInt32 i = 0; i < io->mNumberBuffers; i++) memset(io->mBuffers[i].mData, 0, io->mBuffers[i].mDataByteSize); }

static OSStatus tpCB(void *r, AudioUnitRenderActionFlags *f, const AudioTimeStamp *t, UInt32 b, UInt32 n, AudioBufferList *io) { fill(io, n); return noErr; }

static OSStatus outCB(void *r, AudioUnitRenderActionFlags *f, const AudioTimeStamp *t, UInt32 b, UInt32 n, AudioBufferList *io) {
    if (!C.playing) { silence(io); *f |= kAudioUnitRenderAction_OutputIsSilence; return noErr; }
    if (C.useTP) { if (AudioUnitRender(TPU, f, t, 0, n, io) != noErr) silence(io); return noErr; }
    fill(io, n); return noErr;
}

static AudioStreamBasicDescription FMT(void) {
    AudioStreamBasicDescription f; memset(&f, 0, sizeof f);
    f.mSampleRate = 44100; f.mFormatID = kAudioFormatLinearPCM;
    f.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    f.mBytesPerPacket = 4; f.mFramesPerPacket = 1; f.mBytesPerFrame = 4; f.mChannelsPerFrame = 2; f.mBitsPerChannel = 32;
    return f;
}

@implementation TBPlayer { BOOL _ready, _outRunning; NSTimer *_tick; int _ticks; }
@synthesize curId = _curId, playing = _playing, sleepAt = _sleepAt;

+ (TBPlayer *)shared { static TBPlayer *p; static dispatch_once_t o; dispatch_once(&o, ^{ p = [TBPlayer new]; C.g = 1; }); return p; }

- (void)startSession {
    AVAudioSession *as = [AVAudioSession sharedInstance];
    [as setCategory:AVAudioSessionCategoryPlayback error:nil];
    [as setPreferredSampleRate:44100 error:nil];
    [as setPreferredIOBufferDuration:0.0464 error:nil];
    [as setActive:YES error:nil];
    [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        if ([n.userInfo[AVAudioSessionInterruptionTypeKey] intValue] == AVAudioSessionInterruptionTypeBegan) { if (_playing) [self toggle]; }
        else [[AVAudioSession sharedInstance] setActive:YES error:nil];
    }];
    _tick = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
}

- (void)tick {
    TBStore *s = [TBStore shared];
    if (_playing) {
        s.secs += 1; if (((int)s.secs) % 30 == 0) [s save];
        if (++_ticks % 10 == 0) [self nowPlaying];
    }
    if (_sleepAt > 0 && [[NSDate date] timeIntervalSince1970] >= _sleepAt) { _sleepAt = 0; if (_playing) [self toggle]; }
}
- (void)setSleepMinutes:(int)m { _sleepAt = m > 0 ? [[NSDate date] timeIntervalSince1970] + m * 60 : 0; }

- (void)producer {
    static struct { UInt32 n; AudioBuffer b[2]; } bl;
    for (;;) {
        int did = 0;
        pthread_mutex_lock(&M);
        if (C.file && !C.eof && (RING - (C.wr - C.rd)) >= 4096) {
            bl.n = 2;
            for (int i = 0; i < 2; i++) { bl.b[i].mNumberChannels = 1; bl.b[i].mDataByteSize = 4096 * 4; bl.b[i].mData = TMP[i]; }
            UInt32 fr = 4096;
            OSStatus s = ExtAudioFileRead(C.file, &fr, (AudioBufferList *)&bl);
            if (s != noErr || fr == 0) C.eof = 1;
            else {
                SInt64 w = C.wr;
                for (UInt32 i = 0; i < fr; i++) { UInt32 ix = (UInt32)((w + i) & (RING - 1)); RL[ix] = TMP[0][i]; RR[ix] = TMP[1][i]; }
                OSMemoryBarrier(); C.wr = w + fr; did = 1;
            }
        }
        pthread_mutex_unlock(&M);
        if (!did) usleep(6000);
    }
}

- (void)setup {
    if (_ready) return;
    AudioComponentDescription od = {kAudioUnitType_Output, kAudioUnitSubType_RemoteIO, kAudioUnitManufacturer_Apple, 0, 0};
    AudioComponentDescription td = {kAudioUnitType_FormatConverter, kAudioUnitSubType_NewTimePitch, kAudioUnitManufacturer_Apple, 0, 0};
    AudioComponentInstanceNew(AudioComponentFindNext(NULL, &od), &OUTU);
    AudioComponentInstanceNew(AudioComponentFindNext(NULL, &td), &TPU);
    AudioStreamBasicDescription f = FMT();
    // IMPORTANT: iOS asks for bigger chunks when the screen is locked; every unit must accept them or audio goes silent.
    UInt32 mf = 8192;
    AudioUnitSetProperty(OUTU, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &mf, sizeof mf);
    AudioUnitSetProperty(TPU,  kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &mf, sizeof mf);
    OSStatus e1 = AudioUnitSetProperty(OUTU, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &f, sizeof f);
    AURenderCallbackStruct ocb = {outCB, NULL};
    OSStatus e2 = AudioUnitSetProperty(OUTU, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &ocb, sizeof ocb);
    OSStatus e3 = AudioUnitInitialize(OUTU);
    TBLog([NSString stringWithFormat:@"setup: out format %d, callback %d, init %d", (int)e1, (int)e2, (int)e3]);
    AudioUnitSetProperty(TPU, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,  0, &f, sizeof f);
    AudioUnitSetProperty(TPU, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &f, sizeof f);
    AURenderCallbackStruct tcb = {tpCB, NULL};
    AudioUnitSetProperty(TPU, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &tcb, sizeof tcb);
    OSStatus e4 = AudioUnitInitialize(TPU);
    TBLog([NSString stringWithFormat:@"setup: timepitch init %d", (int)e4]);
    [NSThread detachNewThreadSelector:@selector(producer) toTarget:self withObject:nil];
    _ready = YES;
}

- (void)applyEQ {
    TBStore *s = [TBStore shared]; float mx = 0; BOOL flat = YES;
    for (int i = 0; i < 10; i++) {
        float db = [s.eqGains[i] floatValue]; if (db > mx) mx = db; if (db != 0) flat = NO;
        double A = pow(10, db / 40.0), w = 2 * M_PI * EQF[i] / 44100.0, al = sin(w) / (2 * 1.2), c = cos(w), a0 = 1 + al / A;
        C.b[i][0] = (1 + al * A) / a0; C.b[i][1] = (-2 * c) / a0; C.b[i][2] = (1 - al * A) / a0;
        C.b[i][3] = (-2 * c) / a0;     C.b[i][4] = (1 - al / A) / a0;
    }
    C.g = pow(10, -mx / 40.0);
    int on = (s.eqOn && !flat) ? 1 : 0;
    if (on && !C.eq) memset(C.z, 0, sizeof C.z);
    C.eq = on;
}

- (void)applyRate {
    if (!_ready) return;
    float r = [[[TBStore shared] song:_curId][@"rate"] floatValue]; if (r < .5) r = 1;
    float cents = [TBStore shared].keepPitch ? 0 : 1200 * log2f(r);
    int tp = (fabsf(r - 1) > .001f || fabsf(cents) > .5f) ? 1 : 0;
    AudioUnitSetParameter(TPU, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, r, 0);
    AudioUnitSetParameter(TPU, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, cents, 0);
    if (tp && !C.useTP) AudioUnitReset(TPU, kAudioUnitScope_Global, 0);
    C.useTP = tp;
}
- (void)setSpeed:(float)r forSong:(NSString *)sid {
    NSMutableDictionary *s = [TBStore shared].songs[sid]; if (!s) return;
    s[@"rate"] = @(r); [[TBStore shared] save];
    if ([sid isEqual:_curId]) { [self applyRate]; [self nowPlaying]; }
    [[NSNotificationCenter defaultCenter] postNotificationName:TBPlayerChanged object:nil];
}

- (void)prime { for (int i = 0; i < 60 && (C.wr - C.rd) < 16384 && !C.eof; i++) usleep(8000); }
- (void)startOut { if (!_outRunning) { OSStatus e = AudioOutputUnitStart(OUTU); TBLog([NSString stringWithFormat:@"start %d", (int)e]); _outRunning = YES; } }
- (void)stopOut { if (_outRunning) { AudioOutputUnitStop(OUTU); _outRunning = NO; } }

- (void)play:(NSString *)sid inList:(NSArray *)l { self.list = l ?: @[sid]; [self load:sid]; }

- (void)load:(NSString *)sid {
    TBStore *st = [TBStore shared]; NSDictionary *s = [st song:sid]; if (!s) return;
    [self setup];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    C.playing = 0; usleep(40000);
    ExtAudioFileRef f;
    OSStatus oe = ExtAudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:[st path:s]], &f);
    if (oe != noErr) { TBLog([NSString stringWithFormat:@"open failed %d: %@", (int)oe, [st path:s]]); return; }
    AudioStreamBasicDescription fmt = FMT(), fd; UInt32 sz = sizeof fd;
    ExtAudioFileSetProperty(f, kExtAudioFileProperty_ClientDataFormat, sizeof fmt, &fmt);
    ExtAudioFileGetProperty(f, kExtAudioFileProperty_FileDataFormat, &sz, &fd);
    pthread_mutex_lock(&M);
    ExtAudioFileRef old = C.file; C.file = NULL; if (old) ExtAudioFileDispose(old);
    memset(C.z, 0, sizeof C.z);
    C.wr = 0; C.rd = 0; C.pos = 0; C.eof = 0; C.ended = 0;
    C.fileSR = fd.mSampleRate > 0 ? fd.mSampleRate : 44100;
    C.file = f;
    pthread_mutex_unlock(&M);
    _curId = sid;
    [self applyRate]; [self applyEQ]; [self prime];
    C.playing = 1; _playing = YES; [self startOut];
    TBLog([NSString stringWithFormat:@"play %@ ring=%d eof=%d", s[@"title"], (int)(C.wr - C.rd), (int)C.eof]);
    st.plays[sid] = @([st.plays[sid] intValue] + 1);
    [st.recent removeObject:sid]; [st.recent insertObject:sid atIndex:0];
    while (st.recent.count > 50) [st.recent removeLastObject];
    [st save]; [self nowPlaying];
    [[NSNotificationCenter defaultCenter] postNotificationName:TBPlayerChanged object:nil];
}

- (void)toggle {
    if (!_curId) return;
    _playing = !_playing; C.playing = _playing;
    if (_playing) [self startOut]; else { usleep(30000); [self stopOut]; }
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
    else { if (_playing) [self toggle]; [self seek:0]; }
}
- (void)prev {
    if ([self position] > 3) { [self seek:0]; return; }
    NSUInteger i = [_list indexOfObject:_curId];
    [self load:(i != NSNotFound && i > 0) ? _list[i - 1] : _curId];
}
- (void)seek:(double)sec {
    if (!C.file) return;
    int was = C.playing; C.playing = 0; usleep(40000);
    pthread_mutex_lock(&M);
    ExtAudioFileSeek(C.file, (SInt64)(sec * C.fileSR));
    C.wr = 0; C.rd = 0; C.eof = 0; C.ended = 0; C.pos = (SInt64)(sec * 44100);
    pthread_mutex_unlock(&M);
    AudioUnitReset(TPU, kAudioUnitScope_Global, 0);
    [self prime]; C.playing = was;
}
- (double)position { return C.pos / 44100.0; }
- (double)duration { NSDictionary *s = [[TBStore shared] song:_curId]; return s ? [s[@"dur"] doubleValue] : 0; }

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
