# CHERIoT: No Mutable Globals and No Shared Objects

This note describes two experimental build-time profiles intended for CHERIoT
and similar compartment systems:

- `WOLFSSL_NO_MUTABLE_GLOBALS`
- `WOLFSSL_NO_SHARED_OBJECTS`

The goal is to let wolfSSL be used in a CHERIoT TLS compartment without
library-wide writable state that can couple otherwise isolated TLS flows.

## Threat Model

CHERIoT compartments make mutable globals part of a compartment's authority.
If one TLS compartment instance has writable library globals, then a compromise
in one TLS flow may be able to affect later or concurrent flows through that
state.

The intended CHERIoT shape is closer to BearSSL: all mutable TLS state for a
connection is reachable from an explicit object, normally a sealed capability
owned by the TLS wrapper. Shared code may contain constants, but should not
contain writable process- or compartment-wide state.

Useful background:

- CHERIoT shared libraries are intended to contain reusable code and read-only
  data, not mutable globals: <https://cheriot.org/book/concepts.html>
- The CHERIoT networking write-up describes the desired TLS property: one
  connection object's state should not be reachable from another TLS thread:
  <https://cheriot.org/rtos/networking/auditing/2024/03/08/cheriot-network-stack.html>
- BearSSL advertises a reentrant, no-mutable-global style that fits this model:
  <https://bearssl.org/>

## `WOLFSSL_NO_MUTABLE_GLOBALS`

`WOLFSSL_NO_MUTABLE_GLOBALS` removes or rejects wolfSSL features that require
file-scope writable state in the enabled code path. It is a constrained profile,
not a promise that every wolfSSL feature remains available.

The profile currently:

- Forces `NO_SESSION_CACHE`.
- Forces `NO_FILESYSTEM`.
- Disables OpenSSL RAND callback compatibility with
  `WOLFSSL_NO_OPENSSL_RAND_CB`.
- Disables the default session-ticket encryption callback with
  `WOLFSSL_NO_DEF_TICKET_ENC_CB`.
- Disables wolfSSL's global allocator callback table unless static memory is in
  use.
- Makes the static-memory global heap hint unavailable; static-memory callers
  must pass explicit heap hints.
- Removes `globalRNG`, `initGlobalRNG`, and `globalRNGMutex`.
- Makes `wolfSSL_Init()` / `wolfSSL_Cleanup()` no-ops.
- Makes `wolfCrypt_Init()` / `wolfCrypt_Cleanup()` no-ops.
- Removes Hash_DRBG runtime selection globals and mutexes. The DRBG choice is
  compile-time fixed.
- Disables the OpenSSL-style static error string fallback; callers must pass a
  buffer to `wolfSSL_ERR_error_string()`.

The profile rejects known incompatible features, including:

- OpenSSL compatibility profiles (`OPENSSL_EXTRA`, `OPENSSL_ALL`,
  `OPENSSL_EXTRA_X509_SMALL`, `WOLFSSL_NGINX`, `WOLFSSL_HAPROXY`, `HAVE_LIGHTY`)
- Runtime seed callback (`WC_RNG_SEED_CB`)
- Global crypto callback / async device registries (`WOLF_CRYPTO_CB`,
  `WOLFSSL_ASYNC_CRYPT`)
- System crypto policy (`WOLFSSL_SYS_CRYPTO_POLICY`)
- `atexit` cleanup (`HAVE_ATEXIT`)
- Global memory/debug/logging state (`WOLFSSL_TRACK_MEMORY`,
  `WOLFSSL_DEBUG_MEMORY`, `WOLFSSL_CHECK_MEM_ZERO`, `DEBUG_WOLFSSL`, etc.)
- RNG bank support (`WC_RNG_BANK_SUPPORT`)
- CRL monitor threads (`HAVE_CRL_MONITOR`)
- Whitewood netRandom global context (`HAVE_WNR`)
- ECC/global cache features (`FP_ECC`, `HAVE_OID_ENCODING`, `ECC_CACHE_CURVE`)
- Sniffer support (`WOLFSSL_SNIFFER`)

Entropy should be integrated through compile-time hooks such as
`CUSTOM_RAND_GENERATE_BLOCK` or equivalent platform-specific seed generation,
not via `wc_SetSeed_Cb()`.

## `WOLFSSL_NO_SHARED_OBJECTS`

`WOLFSSL_NO_SHARED_OBJECTS` implies `WOLFSSL_NO_MUTABLE_GLOBALS`.

This profile further constrains wolfSSL object ownership so that application
code cannot intentionally share major mutable TLS objects between flows.

The current implementation:

- Adds a one-live-`WOLFSSL` guard to `WOLFSSL_CTX`.
- Reserves that guard under the existing per-`WOLFSSL_CTX` reference mutex, so
  two threads racing on the same context cannot both create a live `WOLFSSL`.
- Allows wolfSSL's internal `WOLFSSL` to `WOLFSSL_CTX` reference, because the
  connection object must retain its context.
- Makes public `wolfSSL_CTX_up_ref()` fail.
- Makes public `wolfSSL_SESSION_up_ref()` fail.
- Makes `wolfSSL_set_SSL_CTX()` fail.
- Makes `wolfSSL_write_dup()` fail.
- Prevents switching a live `WOLFSSL` to another context.
- Rejects `SINGLE_THREADED`, because that would make the per-context ownership
  reservation non-atomic.

This is not a replacement for the CHERIoT wrapper's ownership discipline. The
wrapper should still allocate one sealed TLS-flow object and avoid passing the
same `WOLFSSL_CTX`, `WOLFSSL`, `WOLFSSL_SESSION`, or heap object to multiple
flows.

## Intended CHERIoT Object Model

A CHERIoT TLS wrapper should allocate one sealed object per TLS flow containing
at least:

```c
struct cheriot_wolfssl_flow {
    WOLFSSL_CTX* ctx;
    WOLFSSL* ssl;
    void* heap_or_allocator_capability;
    /* Transport callback state. */
    /* Trust anchors / certificate material for this flow or endpoint. */
};
```

The wrapper owns this object and seals it when returning it to callers. Between
calls, the TLS compartment should be able to recover the state only by
unsealing the flow capability. No wolfSSL mutable state should be reachable
through a global capability.

## Configuration Sketch

A CHERIoT `user_settings.h` would start with:

```c
#define WOLFSSL_NO_SHARED_OBJECTS
#define WOLFSSL_USER_IO
#define NO_FILESYSTEM
#define NO_SESSION_CACHE
#define HAVE_ECC
#define WOLFSSL_TLS13

/* Use a CHERIoT-specific allocator or static memory. */
#define XMALLOC_USER

/* Prefer a compile-time entropy hook over runtime global seed callbacks. */
#define CUSTOM_RAND_GENERATE_BLOCK cheriot_rng_generate_block
```

Do not define `SINGLE_THREADED` with `WOLFSSL_NO_SHARED_OBJECTS`. The profile is
for builds where multiple threads may try to enter the TLS compartment.

Exact cipher, certificate, and memory settings still need to be tuned to the
CHERIoT port's size and feature requirements.

## Audit Checks

For the no-mutable-globals profile, the CHERIoT build should audit generated
objects, not only source text. A useful first pass is:

```sh
nm -S --defined-only libwolfssl.a | grep ' [BbDd] '
```

Expected results should be limited to toolchain/runtime symbols or explicitly
reviewed per-object data. The profile should not emit wolfSSL-owned writable
globals such as RNGs, caches, callback tables, or init counters.

Source-level checks are still useful:

```sh
git grep -n "static .*wolfSSL_Mutex" -- src wolfcrypt/src wolfssl
git grep -n "static .*WC_THREADSHARED" -- src wolfcrypt/src wolfssl
git grep -n "static volatile" -- src wolfcrypt/src wolfssl
```

Each hit in a `WOLFSSL_NO_MUTABLE_GLOBALS` build must either be compiled out,
be read-only, or be explicitly justified.

## Current Limitations

This branch is an implementation sketch, not a completed CHERIoT certification
profile.

Known areas that still need target-side audit:

- Hardware crypto backend globals are rejected broadly, not individually
  converted to per-object state.
- The OpenSSL compatibility surface is rejected rather than adapted.
- Some non-default wolfCrypt modules may still contain writable globals under
  feature macros not covered by this initial profile.
- The profile assumes application code follows the one-sealed-flow-object model.
  It cannot prove capability ownership outside wolfSSL.

## Upstreaming Strategy

The safest upstream path is incremental:

1. Land `WOLFSSL_NO_MUTABLE_GLOBALS` as a constrained software-only profile.
2. Add CI that builds a small TLS 1.3/ECC configuration with that macro.
3. Audit object-file writable symbols for that configuration.
4. Land `WOLFSSL_NO_SHARED_OBJECTS` as an additional ownership discipline.
5. Extend feature support only when each feature can prove it has no writable
   library-wide state.
