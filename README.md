# OpenFile

[![Build Status](https://travis-ci.org/FreeSlave/openfile.svg?branch=master)](https://travis-ci.org/FreeSlave/openfile)
[![Windows Build Status](https://ci.appveyor.com/api/projects/status/github/FreeSlave/openfile?branch=master&svg=true)](https://ci.appveyor.com/project/FreeSlave/openfile)
[![Coverage Status](https://coveralls.io/repos/FreeSlave/openfile/badge.svg?branch=master&service=github)](https://coveralls.io/github/FreeSlave/openfile?branch=master)

**OpenFile** library provides functions for opening *std.stdio.File* using a set of symbolic constants instead of C-style string as a file access mode.
This approach allows setting a file access mode which is not possible or non-portable to set via string literals.
E.g. an exclusive mode which atomically ensures that the file does not exist upon creating.
Also someone might just prefer symbolic constants over string literals.
