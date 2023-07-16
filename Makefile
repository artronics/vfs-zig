test-main:
	zig test ./src/main.zig

test-vfs:
	zig test ./src/vfs.zig

test-memory:
	zig test -femit-bin=./zig-out/lib/memory-test ./src/memory.zig
