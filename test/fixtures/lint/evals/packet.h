/*
 * packet.h -- wire format of a telemetry frame.
 *
 * Every frame starts with a fixed 12-byte header, big-endian, followed
 * by `length` bytes of payload. `type` selects the payload schema;
 * `seq` wraps at 2^32; `flags` bit 0 marks a retransmission and bit 1
 * a compressed payload; the remaining 24 bits are reserved and sent as
 * zero.
 */

#ifndef PACKET_H
#define PACKET_H

#include <stdint.h>

struct frame_header {
    uint16_t type;      /* payload schema */
    uint16_t length;    /* payload bytes that follow */
    uint32_t seq;       /* sequence number, wraps */
    uint8_t  flags;     /* bit 0 retransmit, bit 1 compressed */
    uint8_t  reserved[3];
};

#define FRAME_FLAG_RETRANSMIT 0x01
#define FRAME_FLAG_COMPRESSED 0x02

#endif
