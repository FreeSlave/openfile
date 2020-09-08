/**
 * Open $(B std.stdio.File) using a set of symbolic constants as a file access mode.
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * Copyright:
 *  Roman Chistokhodov, 2020
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */

module openfile;

public import std.stdio : File;

/// Flags for file open mode.
enum OpenMode
{
    /// Open in read mode.
    read = 1 << 0,
    /**
        * Open in write mode, dont' truncate.
        * Create a file if `existingOnly` flag is not provided.
        */
    update = 1 << 1,
    /**
        * Open in write mode, truncate if exists.
        * Create a file if `existingOnly` flag is not provided.
        */
    truncate = 1 << 2,
    /**
        * Open in write mode. Append to the end on writing.
        * Create a file if `existingOnly` flag is not provided.
        *
        * Note that it has a special meaning on Posix:
        * the file opened in append mode will have write operations
        * happening at the end of the file regardless of manual seek position changing.
        */
    append = 1 << 3,
    /**
        * Open in write mode. Create file only if it does not exist, error otherwise.
        * The check for existence and the file creation is an atomical operation.
        * Use this flag when need to ensure that the file with such name did not exist.
        */
    createNew = 1 << 4,
    /**
        * Don't create file if it does not exist when opening in write mode.
        * This flag is not necessary when opening a file in read-only mode.
        * This flag can't be used together with `OpenMode.createNew` flag.
        */
    existingOnly = 1 << 5,
}

private bool hasAnyWriteFlag(OpenMode openMode) @safe nothrow pure @nogc
{
    with(OpenMode) return (openMode & (update | truncate | append | createNew)) != 0;
}

private string modezFromOpenMode(OpenMode openMode) @safe
{
    const bool anyWrite = hasAnyWriteFlag(openMode);
    if (openMode & OpenMode.read)
    {
        if (anyWrite)
        {
            if (openMode & OpenMode.append)
                return "a+";
            else if (openMode & OpenMode.existingOnly)
                return "r+";
            else
                return "w+";
        }
        else return "r";
    }
    else
    {
        assert(anyWrite);
        if (openMode & OpenMode.append)
            return "a";
        else
            return "w";
    }
}

version(Posix)
{
private:
    import core.sys.posix.fcntl : O_RDWR, O_RDONLY, O_WRONLY, O_TRUNC, O_APPEND, O_EXCL, O_CREAT, mode_t;

    mode_t unixModeFromOpenMode(OpenMode openMode) @safe @nogc nothrow pure
    {
        mode_t mode;
        const bool anyWrite = hasAnyWriteFlag(openMode);
        const bool existing = (openMode & OpenMode.existingOnly) != 0;
        const bool hasRead = (openMode & OpenMode.read) != 0;
        if (hasRead && anyWrite)
            mode |= O_RDWR;
        else if (hasRead)
            mode |= O_RDONLY;
        else if (anyWrite)
            mode |= O_WRONLY;

        if (anyWrite && !existing)
            mode |= O_CREAT;

        if (openMode & OpenMode.truncate)
            mode |= O_TRUNC;
        if (openMode & OpenMode.append)
            mode |= O_APPEND;
        if (openMode & OpenMode.createNew)
            mode |= O_EXCL;
        return mode;
    }

    unittest
    {
        assert(unixModeFromOpenMode(OpenMode.read | OpenMode.truncate) == (O_RDWR | O_TRUNC | O_CREAT));
    }

    int openFd(string name, OpenMode openMode) @trusted
    {
        import std.exception : errnoEnforce;
        import std.internal.cstring : tempCString;
        import std.conv : octal;
        static import core.sys.posix.fcntl;

        mode_t mode = unixModeFromOpenMode(openMode);

        auto namez = name.tempCString();
        int fd;
        if (mode & O_CREAT)
            fd = core.sys.posix.fcntl.open(namez, mode, octal!666);
        else
            fd = core.sys.posix.fcntl.open(namez, mode);
        errnoEnforce(fd >= 0);
        return fd;
    }
}

version(Windows)
{
private:
    import core.sys.windows.core : HANDLE;

    HANDLE openHandle(string name, OpenMode openMode) @trusted
    {
        import std.utf : toUTF16z;
		import std.windows.syserror : wenforce;
        import core.sys.windows.core : FILE_ATTRIBUTE_NORMAL, FILE_FLAG_SEQUENTIAL_SCAN,
                                        GENERIC_READ, GENERIC_WRITE, FILE_SHARE_READ, FILE_SHARE_WRITE,
                                        TRUNCATE_EXISTING, OPEN_EXISTING, CREATE_ALWAYS,
                                        CREATE_NEW, OPEN_ALWAYS, INVALID_HANDLE_VALUE,
                                        FILE_END, INVALID_SET_FILE_POINTER, DWORD,
                                        CreateFileW, SetFilePointer;

        auto namez = name.toUTF16z;
        const bool anyWrite = hasAnyWriteFlag(openMode);
        const bool existing = (openMode & OpenMode.existingOnly) != 0;
        const bool hasRead = (openMode & OpenMode.read) != 0;

        DWORD desiredAccess = 0;
        DWORD shareMode = 0;
        DWORD creationDisposition = 0;
        DWORD flags = FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN;

        if (hasRead)
        {
            desiredAccess |= GENERIC_READ;
            shareMode |= FILE_SHARE_READ;
        }
        if (anyWrite)
        {
            desiredAccess |= GENERIC_WRITE;
            shareMode |= FILE_SHARE_WRITE;
        }

        if ((hasRead && !anyWrite) || existing)
        {
            if (openMode & OpenMode.truncate)
                creationDisposition = TRUNCATE_EXISTING;
            else
                creationDisposition = OPEN_EXISTING;
        }
        else if (openMode & OpenMode.createNew)
        {
            creationDisposition = CREATE_NEW;
        }
		else if (openMode & OpenMode.truncate)
        {
            creationDisposition = CREATE_ALWAYS;
        }
        else if (anyWrite)
        {
            creationDisposition = OPEN_ALWAYS;
        }
        HANDLE h = CreateFileW(namez, desiredAccess, shareMode, null, creationDisposition, flags, HANDLE.init);
        wenforce(h != INVALID_HANDLE_VALUE, name);
        if (openMode & OpenMode.append)
            wenforce(SetFilePointer(h, 0, null, FILE_END) != INVALID_SET_FILE_POINTER, name);
        return h;
    }
}

/**
 * Open file using name and symbolic access mode.
 * See_Also: $(D openfile.sopen)
 */
File openFile(string name, OpenMode mode) @trusted
{
    import std.exception : enforce;
    enforce((mode & OpenMode.read) != 0 || hasAnyWriteFlag(mode),
            "read flag or some of write flags must be provided in open mode");
    enforce(!((mode & OpenMode.createNew) != 0 && (mode & OpenMode.existingOnly) != 0),
            "createNew and existingOnly can't be used together in open mode");

    version(Posix)
    {
        import core.sys.posix.unistd : close;
        int fd = openFd(name, mode);
        scope(failure) close(fd);
        File file;
        file.fdopen(fd, modezFromOpenMode(mode));
        return file;
    }
    else version(Windows)
    {
        import core.sys.windows.core : CloseHandle;
        HANDLE handle = openHandle(name, mode);
        scope(failure) CloseHandle(handle);
        File file;
        file.windowsHandleOpen(handle, modezFromOpenMode(mode));
        return file;
    }
}

/// Open file using name and symbolic access mode. Convenient function for UFCS. Calls $(B std.stdio.detach) before assigning a new file handle.
void sopen(ref scope File file, string name, OpenMode mode) @safe
{
	file.detach();
	file = openFile(name, mode);
}

///
unittest
{
    static import std.file;
    import std.path : buildPath;
    import std.exception : assertThrown;
    import std.process : thisProcessID;
    import std.conv : to;

    auto deleteme = buildPath(std.file.tempDir(), "deleteme.openfile.unittest.pid" ~ to!string(thisProcessID));
    scope(exit) std.file.remove(deleteme);

    // bad set of flags
    assertThrown(openFile(deleteme, OpenMode.createNew | OpenMode.existingOnly));
    assertThrown(openFile(deleteme, OpenMode.existingOnly));

    // opening non-existent file
    assertThrown(openFile(deleteme, OpenMode.read));
    assertThrown(openFile(deleteme, OpenMode.update | OpenMode.existingOnly));

    File f = openFile(deleteme, OpenMode.read | OpenMode.truncate | OpenMode.createNew);
    f.write("Hello");
    f.rewind();
    assert(f.readln() == "Hello");

    assertThrown(openFile(deleteme, OpenMode.createNew));

    f.sopen(deleteme, OpenMode.append | OpenMode.existingOnly);
    f.write(" world");

    f.sopen(deleteme, OpenMode.update | OpenMode.existingOnly);
    f.seek(6);
    f.write("sco");

    f.sopen(deleteme, OpenMode.read);
    assert(f.readln() == "Hello scold");

    f.sopen(deleteme, OpenMode.read | OpenMode.update | OpenMode.existingOnly);
    f.write("Yo");
    f.rewind();
    assert(f.readln() == "Yollo scold");

    f.sopen(deleteme, OpenMode.read | OpenMode.append | OpenMode.existingOnly);
    f.write("ing");
    f.rewind();
    assert(f.readln() == "Yollo scolding");

    auto deleteme2 = buildPath(std.file.tempDir(), "deleteme2.openfile.unittest.pid" ~ to!string(thisProcessID));
    scope(exit) std.file.remove(deleteme2);

	assertThrown(f.sopen(deleteme2, OpenMode.truncate | OpenMode.existingOnly));

    f.sopen(deleteme2, OpenMode.read | OpenMode.update | OpenMode.createNew);
    f.write("baz");
    f.rewind();
    assert(f.readln() == "baz");
    f.seek(3);
    f.write("bar");
    f.rewind();
    assert(f.readln() == "bazbar");

	f.sopen(deleteme2, OpenMode.read | OpenMode.truncate | OpenMode.existingOnly);
	f.write("some");
	f.rewind();
	assert(f.readln() == "some");

    f.close();
}
