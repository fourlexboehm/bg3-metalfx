#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <dlfcn.h>
#include <cstdio>
#include <vector>
#include <cmath>
#import <MetalFX/MetalFX.h>
#include "../vendor/fsr4-native-macos/src/fsr4_live.h"
int main(int argc, char** argv) { @autoreleasepool {
    if (argc != 2 && argc != 3) return 2;
    const unsigned rw=argc==3?2016:64, rh=argc==3?1260:64;
    const unsigned uw=argc==3?3024:96, uh=argc==3?1890:96;
    void* lib=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);
    if (!lib) {fprintf(stderr,"%s\n",dlerror());return 1;}
    auto encode=(int (*)(const Fsr4LiveFrame*))dlsym(lib,"fsr4_encode_live_frame");
    auto status=(void (*)(Fsr4LiveStatus*))dlsym(lib,"fsr4_live_get_status");
    auto release=(void (*)(void*,void*))dlsym(lib,"fsr4_release_live_owner");
    if(!encode || !status || !release)return 1;
    id<MTLDevice> dev=MTLCreateSystemDefaultDevice();
    id<MTLCommandQueue> queue=[dev newCommandQueue];
    auto texture=[&](MTLPixelFormat fmt,int w,int h) {
        auto d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:fmt width:w height:h mipmapped:NO];
        d.storageMode=MTLStorageModeShared;d.usage=MTLTextureUsageShaderRead|MTLTextureUsageShaderWrite;
        return [dev newTextureWithDescriptor:d];
    };
    auto color=texture(MTLPixelFormatRG11B10Float,rw,rh);
    auto depth=texture(MTLPixelFormatR32Float,rw,rh);
    auto motion=texture(MTLPixelFormatRG16Float,rw,rh);
    auto output=texture(MTLPixelFormatRG11B10Float,uw,uh);
    auto exposure=texture(MTLPixelFormatR16Float,1,1);
    std::vector<uint32_t> c(rw*rh,(13u<<6)|(13u<<17)|(13u<<27));
    std::vector<_Float16> m(rw*rh*2,0);
    std::vector<float> d(rw*rh,0.5f);_Float16 e=1;
    [color replaceRegion:MTLRegionMake2D(0,0,rw,rh) mipmapLevel:0 withBytes:c.data() bytesPerRow:rw*4];
    [depth replaceRegion:MTLRegionMake2D(0,0,rw,rh) mipmapLevel:0 withBytes:d.data() bytesPerRow:rw*4];
    [motion replaceRegion:MTLRegionMake2D(0,0,rw,rh) mipmapLevel:0 withBytes:m.data() bytesPerRow:rw*4];
    [exposure replaceRegion:MTLRegionMake2D(0,0,1,1) mipmapLevel:0 withBytes:&e bytesPerRow:2];
    MTLFXTemporalScalerDescriptor* descriptor=[MTLFXTemporalScalerDescriptor new];
    descriptor.inputWidth=rw;descriptor.inputHeight=rh;
    descriptor.outputWidth=uw;descriptor.outputHeight=uh;
    descriptor.colorTextureFormat=color.pixelFormat;descriptor.depthTextureFormat=depth.pixelFormat;
    descriptor.motionTextureFormat=motion.pixelFormat;descriptor.outputTextureFormat=output.pixelFormat;
    descriptor.autoExposureEnabled=NO;
    id<MTLFXTemporalScaler> scaler=[descriptor newTemporalScalerWithDevice:dev];
    if(!scaler){fprintf(stderr,"MetalFX scaler creation failed\n");return 1;}
    Fsr4LiveFrame f={};
    f.device=(__bridge void*)dev;f.owner=(void*)0x1234;
    f.color=(__bridge void*)color;f.depth=(__bridge void*)depth;
    f.motion=(__bridge void*)motion;f.output=(__bridge void*)output;f.exposure=(__bridge void*)exposure;
    f.rw=rw;f.rh=rh;f.uw=uw;f.uh=uh;f.mvScaleX=f.mvScaleY=-1;f.preExposure=1;
    f.depthReversed=1;
    for(int i=0;i<5;++i) {
        setenv("FSR4_REPLACE",i==3?"0":"1",1);
        auto cb=[queue commandBuffer];f.commandBuffer=(__bridge void*)cb;f.reset=i==0;
        f.jitterX=i*.125f;f.jitterY=-i*.125f;
        scaler.colorTexture=color;scaler.depthTexture=depth;scaler.motionTexture=motion;
        scaler.outputTexture=output;scaler.exposureTexture=exposure;
        scaler.inputContentWidth=rw;scaler.inputContentHeight=rh;
        scaler.jitterOffsetX=f.jitterX;scaler.jitterOffsetY=f.jitterY;
        scaler.motionVectorScaleX=-1;scaler.motionVectorScaleY=-1;
        scaler.depthReversed=YES;scaler.reset=f.reset;
        [scaler encodeToCommandBuffer:cb];
        Fsr4LiveStatus s={};status(&s);int ok=i==3?!s.active:s.active;
        if(!ok){fprintf(stderr,"FSR failed: %s\n",s.reason);return 1;}
        [cb commit];[cb waitUntilCompleted];
        if(cb.error){fprintf(stderr,"GPU failed: %s\n",cb.error.localizedDescription.UTF8String);return 1;}
        printf("Frame %d: FSR active=%d variant=%s\n",i,s.active,s.variant);
    }
    std::vector<uint32_t> out(uw*uh);
    [output getBytes:out.data() bytesPerRow:uw*4 fromRegion:MTLRegionMake2D(0,0,uw,uh) mipmapLevel:0];
    // RG11B10 exponent=31 indicates infinity/NaN. The constant input must produce finite, nonzero output.
    size_t nonzero=0;
    for(uint32_t p:out) {
        if(((p>>6)&31)==31 || ((p>>17)&31)==31 || ((p>>27)&31)==31) return 1;
        nonzero+=p!=0;
    }
    if(!nonzero)return 1;
    scaler=nil;
    puts("PASS: actual MetalFX API hook, four FSR GPU frames, MetalFX fallback/recovery, finite output");
    return 0;
}}
