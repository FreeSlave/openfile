# OpenFile

[![Build Status](https://github.com/FreeSlave/openfile/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/FreeSlave/openfile/actions/workflows/ci.yml)
[![Windows Build Status](https://ci.appveyor.com/api/projects/status/github/FreeSlave/openfile?branch=master&svg=true)](https://ci.appveyor.com/project/FreeSlave/openfile)
[![Coverage Status](https://coveralls.io/repos/FreeSlave/openfile/badge.svg?branch=master&service=github)](https://coveralls.io/github/FreeSlave/openfile?branch=master)

**OpenFile** library provides functions for opening *std.stdio.File* using a set of symbolic constants instead of C-style string as a file access mode.
This approach allows setting a file access mode which is not possible or non-portable to express via string literals.
E.g. an exclusive mode which atomically ensures that the file does not exist upon creating.
Also someone might just prefer symbolic constants over string literals.

```
import openfile;

// Open a file in write mod and ensure that this is a new file with such name 
// avoiding an accidental change of data written by some other process and ensuring that no other file with such name exists at the time of opening.
File f = openFile("test.txt", OpenMode.createNew);
```
