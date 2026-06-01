#!/usr/bin/env python3
# Patches libsystemd-shared-257.so (Debian 13 trixie amd64) so that
# cg_create and cg_attach silently succeed when /sys/fs/cgroup is read-only.
import pathlib
import sys

SO = pathlib.Path(
    '/usr/lib/x86_64-linux-gnu/systemd/libsystemd-shared-257.so'
)
data = bytearray(SO.read_bytes())

# cg_create @ 0xcc370: after mkdir fails, jump to success path mov $1,%ebx.
# Patch: js cc4c0 (errno handler)  ->  jmp cc3ef (mov $1,%ebx) + nops
# cg_attach @ 0xcc510: after write_string_file_full fails, zero ebx and
# jump to cleanup return 0.
# Patch: test eax,eax; js cc610  ->  xor ebx,ebx; jmp cc600
PATCHES = [
    # cg_create: ignore mkdirat_parents failure
    # at cc3ca: js cc400 -> jmp cc3ef (success path)
    (
        0xcc3ca,
        bytes([0x78, 0x34]),
        bytes([0xeb, 0x23]),
    ),
    # cg_create: ignore mkdir failure
    # at cc3dc: js cc4c0 (errno handler) -> jmp cc3ef (mov $1,%ebx)
    (
        0xcc3dc,
        bytes([0x0f, 0x88, 0xde, 0x00, 0x00, 0x00]),
        bytes([0xeb, 0x11, 0x90, 0x90, 0x90, 0x90]),
    ),
    # cg_attach: ignore write_string_file_full failure
    # at cc5d8: test eax,eax; js cc610 -> xor ebx,ebx; jmp cc600 (return 0)
    (
        0xcc5d8,
        bytes([0x85, 0xc0, 0x78, 0x34]),
        bytes([0x31, 0xdb, 0xeb, 0x24]),
    ),
    # posix_spawn_wrapper: when open() of phantom cgroup dir fails, jump
    # back to the no-cgroup branch (0x21e3e4) and continue spawning the
    # process without CLONE_INTO_CGROUP. Caller will use cg_attach which
    # is also patched.
    # At cc5c3: js 21e690 -> js 21e3e4 (long backward jump, offset -0x1e5)
    (
        0x21e5c3,
        bytes([0x0f, 0x88, 0xc7, 0x00, 0x00, 0x00]),
        bytes([0x0f, 0x88, 0x1b, 0xfe, 0xff, 0xff]),
    ),
]

for addr, expected, patch in PATCHES:
    actual = bytes(data[addr:addr + len(expected)])
    if actual != expected:
        print(
            f'mismatch at 0x{addr:x}: expected {expected.hex()}, got {actual.hex()}',
            file=sys.stderr,
        )
        sys.exit(1)
    data[addr:addr + len(patch)] = patch
    print(f'patched 0x{addr:x}: {expected.hex()} -> {patch.hex()}')

SO.write_bytes(data)
print('libsystemd-shared-257.so patched OK')
