// Minimal C FFI over iroh for the bmux mobile transport spike.
// See rust/src/lib.rs for semantics. All blocking; call off the main thread.

#ifndef BMUX_IROH_FFI_H
#define BMUX_IROH_FFI_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct BmuxIrohEndpoint BmuxIrohEndpoint;
typedef struct BmuxIrohConnection BmuxIrohConnection;

BmuxIrohEndpoint *bmux_iroh_endpoint_bind(
    bool enable_relay,
    bool accept_connections,
    char *err_buf,
    size_t err_cap);

char *bmux_iroh_endpoint_id(const BmuxIrohEndpoint *endpoint);

char *bmux_iroh_endpoint_route_json(const BmuxIrohEndpoint *endpoint);

int bmux_iroh_endpoint_online(
    BmuxIrohEndpoint *endpoint,
    uint64_t timeout_ms,
    char *err_buf,
    size_t err_cap);

BmuxIrohConnection *bmux_iroh_endpoint_accept(
    BmuxIrohEndpoint *endpoint,
    uint64_t timeout_ms,
    char *err_buf,
    size_t err_cap);

BmuxIrohConnection *bmux_iroh_endpoint_connect(
    BmuxIrohEndpoint *endpoint,
    const char *endpoint_id,
    const char *relay_url,
    const char *const *direct_addrs,
    size_t direct_addr_count,
    uint64_t timeout_ms,
    char *err_buf,
    size_t err_cap);

intptr_t bmux_iroh_connection_recv(
    BmuxIrohConnection *connection,
    uint8_t *buf,
    size_t cap,
    char *err_buf,
    size_t err_cap);

int bmux_iroh_connection_send(
    BmuxIrohConnection *connection,
    const uint8_t *bytes,
    size_t len,
    char *err_buf,
    size_t err_cap);

void bmux_iroh_connection_close(BmuxIrohConnection *connection);

void bmux_iroh_endpoint_close(BmuxIrohEndpoint *endpoint);

void bmux_iroh_string_free(char *string);

#ifdef __cplusplus
}
#endif

#endif // BMUX_IROH_FFI_H
