// Optional native FSR backend. No upstream MetalFX swizzling or CrossOver required.
// Keep the backend loaded for process lifetime: GPU completions may reference it.
static int (*g_fsrEncode)(const Fsr4LiveFrame*) = nullptr;
static void (*g_fsrInvalidate)(void*, void*) = nullptr;
static void (*g_fsrRelease)(void*, void*) = nullptr;
static void (*g_fsrStatus)(Fsr4LiveStatus*) = nullptr;

static void release_fsr4_owner() {
    if (g_fsrRelease && g_scaler) g_fsrRelease((void*)g_device, (void*)g_scaler);
}

static bool encode_fsr4_on(id<MTLCommandBuffer> cb) {
    static bool attempted = false;
    if (!attempted) {
        attempted = true;
        const char* path = getenv("BG3_FSR4_LIBRARY");
        if (path && *path) {
            void* lib = dlopen(path, RTLD_NOW | RTLD_LOCAL);
            if (!lib) log_line_always("FSR4: backend load failed: %s; using MetalFX", dlerror());
            else {
                g_fsrEncode = (int (*)(const Fsr4LiveFrame*))dlsym(lib, "fsr4_encode_live_frame");
                g_fsrInvalidate = (void (*)(void*, void*))dlsym(lib, "fsr4_invalidate_live_owner");
                g_fsrRelease = (void (*)(void*, void*))dlsym(lib, "fsr4_release_live_owner");
                g_fsrStatus = (void (*)(Fsr4LiveStatus*))dlsym(lib, "fsr4_live_get_status");
                if (!g_fsrEncode || !g_fsrInvalidate || !g_fsrRelease || !g_fsrStatus) {
                    g_fsrEncode = nullptr;
                    log_line_always("FSR4: backend ABI incomplete; using MetalFX");
                }
            }
        }
    }
    if (!g_fsrEncode) return false;
    Fsr4LiveFrame f = {};
    f.device = (void*)g_device; f.commandBuffer = (void*)cb; f.owner = (void*)g_scaler;
    f.color = (void*)g_scaler.colorTexture; f.depth = (void*)g_scaler.depthTexture;
    f.motion = (void*)g_scaler.motionTexture; f.output = (void*)g_scaler.outputTexture;
    f.exposure = (void*)g_scaler.exposureTexture;
    f.rw = (uint32_t)g_inW; f.rh = (uint32_t)g_inH;
    f.uw = (uint32_t)g_outW; f.uh = (uint32_t)g_outH;
    f.jitterX = g_scaler.jitterOffsetX; f.jitterY = g_scaler.jitterOffsetY;
    f.mvScaleX = g_scaler.motionVectorScaleX; f.mvScaleY = g_scaler.motionVectorScaleY;
    f.preExposure = g_scaler.preExposure;
    f.reset = g_scaler.reset; f.depthReversed = g_scaler.depthReversed;
    f.jitteredMV = 0; f.outputResMV = 0; f.autoExposure = 0;
    // The game's texture probe must not mistake backend scratch textures for BG3 targets.
    const bool previousAlloc = g_inOwnAlloc;
    bool ok = false;
    g_inOwnAlloc = true;
    @try { ok = g_fsrEncode(&f) != 0; }
    @finally { g_inOwnAlloc = previousAlloc; }
    if (!ok) g_fsrInvalidate(f.device, f.owner);
    // MetalFX history is stale after any successful FSR frame.
    static bool wasFsr = false;
    if (!ok && wasFsr) g_scaler.reset = YES;
    static int last = -1;
    if (last != (int)ok) {
        Fsr4LiveStatus status = {}; g_fsrStatus(&status);
        log_line_always("FSR4 BACKEND: %s (%s)", ok ? "ACTIVE" : "FALLBACK to MetalFX",
                        ok ? status.variant : status.reason);
        last = (int)ok;
    }
    wasFsr = ok;
    return ok;
}
