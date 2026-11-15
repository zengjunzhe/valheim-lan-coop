#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <dlfcn.h>
#include <time.h>
static void logline(const char *fmt, ...) {
    FILE *fp = fopen("/tmp/steamapi_shim.log", "a");
    if (!fp) return;
    va_list ap; va_start(ap, fmt);
    fprintf(fp, "%ld ", (long)time(NULL)); vfprintf(fp, fmt, ap); fputc('\n', fp);
    va_end(ap); fclose(fp);
}
static void *emu_fn(const char *name) {
    static void *h = 0;
    if (!h) h = dlopen("libsteam_api_emu.dylib", RTLD_LAZY | RTLD_GLOBAL);
    if (!h) { logline("dlopen emu FAILED: %s", dlerror()); return 0; }
    return dlsym(h, name);
}
#define WRAP(ret, fn, label) \
__attribute__((visibility("default"))) ret fn(void) { \
    static ret (*real)(void) = 0; if (!real) real = (ret (*)(void))emu_fn(#fn); \
    ret p = real ? real() : 0; logline(label " -> %p", (void*)p); return p; }

WRAP(int, SteamAPI_Init, "INIT")

/* SNS 关键动作：拦下每一次调用 */
__attribute__((visibility("default"))) uint32_t SteamAPI_ISteamNetworkingSockets_CreateListenSocketP2P(void *s, int vport, int n, void *opts) {
    static uint32_t (*real)(void*,int,int,void*) = 0;
    if (!real) real = (uint32_t(*)(void*,int,int,void*))emu_fn("SteamAPI_ISteamNetworkingSockets_CreateListenSocketP2P");
    uint32_t r = real ? real(s,vport,n,opts) : 0;
    logline("CreateListenSocketP2P(iface=%p vport=%d) -> %u", s, vport, r);
    return r;
}
__attribute__((visibility("default"))) uint32_t SteamAPI_ISteamNetworkingSockets_CreateListenSocketIP(void *s, int local, int n, void *opts) {
    static uint32_t (*real)(void*,int,int,void*) = 0;
    if (!real) real = (uint32_t(*)(void*,int,int,void*))emu_fn("SteamAPI_ISteamNetworkingSockets_CreateListenSocketIP");
    uint32_t r = real ? real(s,local,n,opts) : 0;
    logline("CreateListenSocketIP(iface=%p) -> %u", s, r);
    return r;
}
__attribute__((visibility("default"))) uint32_t SteamAPI_ISteamNetworkingSockets_ConnectP2P(void *s, void *ident, int vport, int n, void *opts) {
    static uint32_t (*real)(void*,void*,int,int,void*) = 0;
    if (!real) real = (uint32_t(*)(void*,void*,int,int,void*))emu_fn("SteamAPI_ISteamNetworkingSockets_ConnectP2P");
    uint32_t r = real ? real(s,ident,vport,n,opts) : 0;
    logline("ConnectP2P(iface=%p vport=%d) -> %u", s, vport, r);
    return r;
}
__attribute__((visibility("default"))) void *SteamAPI_SteamNetworkingSockets_v012(void) {
    static void *(*real)(void) = 0; if (!real) real = (void*(*)(void))emu_fn("SteamAPI_SteamNetworkingSockets_v009");
    void *p = real ? real() : 0; logline("SNS_v012(getter) -> %p", p); return p; }
__attribute__((visibility("default"))) void *SteamAPI_SteamNetworking_v006(void) {
    static void *(*real)(void) = 0; if (!real) real = (void*(*)(void))emu_fn("SteamAPI_SteamNetworking_v006");
    void *p = real ? real() : 0; logline("Networking_v006 -> %p", p); return p; }
