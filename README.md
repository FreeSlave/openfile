# OpenFile

**OpenFile** library provides functions for opening *std.stdio.File* using a set of symbolic constants instead of C-style string as a file access mode.
This approach allows setting a file access mode which is not possible or non-portable to set via string literals.
E.g. an exclusive mode which atomically ensures that the file does not exist upon creating.
Also someone might just prefer symbolic constants over string literals.
