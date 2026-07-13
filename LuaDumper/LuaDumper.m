// LuaDumper.dylib - Hook luaL_loadbufferx to dump decrypted Lua bytecode
// Build: theos make THEOS_PACKAGE_SCHEME=roothide
// Or compile manually for iOS ARM64

#include <stdio.h>
#include <string.h>
#include <dlfcn.h>
#include <sys/stat.h>

// Hook type for luaL_loadbufferx
// int luaL_loadbufferx(lua_State *L, const char *buff, size_t sz,
//                      const char *name, const char *mode);
typedef int (*luaL_loadbufferx_t)(void *L, const char *buff, 
                                   size_t sz, const char *name, const char *mode);
static luaL_loadbufferx_t original_luaL_loadbufferx = NULL;

static int dump_counter = 0;

// Dump directory - writable on jailbroken/rootless devices
static const char *DUMP_DIR = "/tmp/lua_dump";

static void ensure_dump_dir() {
    struct stat st;
    if (stat(DUMP_DIR, &st) != 0) {
        mkdir(DUMP_DIR, 0755);
    }
}

static int hooked_luaL_loadbufferx(void *L, const char *buff, 
                                    size_t sz, const char *name, 
                                    const char *mode) {
    // Dump the decrypted bytecode
    if (buff && sz > 0) {
        ensure_dump_dir();
        
        // Generate filename from dump counter and name
        char filepath[512];
        if (name && name[0] != '\0') {
            // Clean the name for filename
            char clean_name[256];
            strncpy(clean_name, name, sizeof(clean_name) - 1);
            clean_name[sizeof(clean_name) - 1] = '\0';
            
            // Replace problematic characters
            for (int i = 0; clean_name[i]; i++) {
                if (clean_name[i] == '/' || clean_name[i] == '\\' || 
                    clean_name[i] == ':' || clean_name[i] == ' ') {
                    clean_name[i] = '_';
                }
            }
            
            snprintf(filepath, sizeof(filepath), "%s/%04d_%s.luac", 
                     DUMP_DIR, dump_counter, clean_name);
        } else {
            snprintf(filepath, sizeof(filepath), "%s/%04d_unknown.luac", 
                     DUMP_DIR, dump_counter);
        }
        
        FILE *f = fopen(filepath, "wb");
        if (f) {
            fwrite(buff, 1, sz, f);
            fclose(f);
            printf("[LuaDumper] Dumped %zu bytes to %s (name: %s)\n", 
                   sz, filepath, name ? name : "NULL");
        }
        
        dump_counter++;
    }
    
    // Call the original function
    return original_luaL_loadbufferx(L, buff, sz, name, mode);
}

// Constructor - called when dylib is loaded
__attribute__((constructor))
static void init_lua_dumper(void) {
    printf("[LuaDumper] LuaDumper.dylib loaded!\n");
    printf("[LuaDumper] Dump directory: %s\n", DUMP_DIR);
    
    // Find the libengine.dylib base address
    void *handle = dlopen("libengine.dylib", RTLD_NOW);
    if (!handle) {
        // Try loading by path
        handle = dlopen("/usr/lib/libengine.dylib", RTLD_NOW);
    }
    
    if (handle) {
        // Get the address of luaL_loadbufferx
        original_luaL_loadbufferx = (luaL_loadbufferx_t)dlsym(handle, "luaL_loadbufferx");
        
        if (original_luaL_loadbufferx) {
            printf("[LuaDumper] Found luaL_loadbufferx at %p\n", 
                   (void *)original_luaL_loadbufferx);
            printf("[LuaDumper] Hook installed - will dump decrypted bytecode\n");
        } else {
            printf("[LuaDumper] WARNING: luaL_loadbufferx not found in libengine.dylib\n");
            // Try alternative: luaL_loadbuffer
            original_luaL_loadbufferx = (luaL_loadbufferx_t)dlsym(handle, "luaL_loadbuffer");
            if (original_luaL_loadbufferx) {
                printf("[LuaDumper] Found luaL_loadbuffer at %p (using as fallback)\n", 
                       (void *)original_luaL_loadbufferx);
            } else {
                printf("[LuaDumper] ERROR: No load function found!\n");
            }
        }
    } else {
        printf("[LuaDumper] ERROR: Cannot open libengine.dylib: %s\n", dlerror());
    }
    
    ensure_dump_dir();
    printf("[LuaDumper] Initialization complete\n");
}
