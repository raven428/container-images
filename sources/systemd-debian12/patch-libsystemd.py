#!/usr/bin/env python3
# Patches libsystemd-shared-252.so (Debian 12 bookworm amd64) so that
# cg_create and cg_attach silently succeed when /sys/fs/cgroup is read-only.
import pathlib
import sys

SO = pathlib.Path(
    '/usr/lib/x86_64-linux-gnu/systemd/libsystemd-shared-252.so'
)
data = bytearray(SO.read_bytes())

# cg_create @ 0x9d7f0: after mkdir fails, jump to success path.
# Patch: js 9d8a0  ->  jmp 9d86c (mov $1,%ebx then return)
# cg_attach @ 0x9d950: after write_string_file_ts fails, zero ebx and jump.
# Patch: test eax,eax; js 9da26  ->  xor ebx,ebx; jmp 9da26
PATCHES = [
    (0x9d84a, bytes([0x78, 0x54]),             bytes([0xeb, 0x20])),
    (0x9d9fc, bytes([0x85, 0xc0, 0x78, 0x26]), bytes([0x31, 0xdb, 0xeb, 0x24])),
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
print('libsystemd-shared-252.so patched OK')
