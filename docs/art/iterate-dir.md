---
title: "Go Directory Iterator"
description: "a Go iterator to loop over directory entries efficiently."
---

# A Go Directory Iterator

Now that [Go 1.23 has iterators](https://go.dev/blog/range-functions) – more
precisely, "push" iterators: can we make good use of iterators to optimize
reading directories regarding speed and heap allocations?

> [!WARNING] The following primarily tackles Linux; some aspects might apply to
> other unix-like OSes too.

One thing that has bugged me for a long time is retrieving the entries of a
directory without hopefully as few overhead as possible, namely:

1. no sorting,
2. minimized heap allocations (to avoid pressuring the GC unnecessarily),
3. and "convenience" syscalls to get additional file information that I simply
   never need in my use cases.

As my system discovery tools tend to scan a lot of directories in the
[proc(5)](https://man7.org/linux/man-pages/man5/procfs.5.html) filesystem, any
optimizations here might be be well spent.

## A Quick Go 1.23 Iterator Pattern Recap

> [!QUOTE] An iterator is a function that passes successive elements of a
> sequence to a callback function, conventionally named yield.[^iter]

In particular, passing elements constitutes "pushing":

> [!QUOTE] The standard iterators can be thought of as “push iterators”, which
> push values to the yield function.[^iter]

Of course, you could do the same all the time using "callback" functions; yet Go
1.23 introduces nice syntactic sugar in form of `range` over a `func`.

## Do _Not_(?) Sort

So how do we speed up reading all entries of a directory? For whatever reason,
[`os.ReadDir`](https://pkg.go.dev/os#ReadDir) first reads in _all_ entries in
the specified directory and then sorts them, before returning the sorted slice.
Now, sorting really doesn't add any benefit when scanning through the `procfs`,
but only burns CPU cycles and heap memory.

> [!QUOTE] [...] You can copy the ReadDir source code and customize it. Anyway,
> I think the os.(*File).ReadDir call is hugely slower than the Sort call[...][^reou]

A slightly better performing `ReadDir` should be easy to derive from the
implementation of
[`os.ReadDir`](https://cs.opensource.google/go/go/+/refs/tags/go1.23.4:src/os/dir.go;l=118)
by simply getting rid of the sorting step and replacing the internal `openDir`
with an official `os.Open` (there's no `os.OpenDir`, so much for "_You can copy
the ReadDir source code..._"):

```go
package faf

func ReadDir(name string) ([]DirEntry, error) {
	f, err := os.Open(name)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return f.ReadDir(-1)
}
```

### Go Gopher, Go

So let's do some benchmarking; we start with `os.ReadDir` on a test data
directory with, say, 16 entries.

```go
package faf_test

var (
	direntries []os.DirEntry
)

func bmOsReadDir(b *testing.B, testdatadir string) {
	for n := 0; n < b.N; n++ {
		var err error
		direntries, err = os.ReadDir(testdatadir)
		if err != nil {
			b.Fatalf("cannot read directory, reason: %s", err)
		}
	}
}

func bmFileReadDir(b *testing.B, testdatadir string) {
	for n := 0; n < b.N; n++ {
		dir, err := os.Open(testdatadir)
		if err != nil {
			b.Fatalf("cannot open directory, reason: %s", err)
		}
		direntries, err = dir.ReadDir(-1)
		dir.Close()
		if err != nil {
			b.Fatalf("cannot read directory, reason: %s", err)
		}
	}
}
```

In order to benchmark with a different number of directory entries, let's create
a configurable number of directory entries in a temporary directory. Derived
from its original intended usecases, these directory entries are simply empty
directories with names that are decimal numbers, like the PID-named directories
in `/proc/`.

```go
var testdataDirEntriesNum uint // number of fake process directory entries to create for benchmarking

func init() {
	flag.UintVar(&testdataDirEntriesNum, "dir-entries", 1024,
		"number of directory entries to use in ReadDir-related benchmarks")
}

func BenchmarkReadDir(b *testing.B) {
	testdatadir := b.TempDir()
	b.Logf("using transient testdata directory %s", testdatadir)
	for num := range testdataDirEntriesNum {
		if err := os.Mkdir(testdatadir+"/"+strconv.FormatUint(uint64(num+1), 10), 0755); err != nil {
			b.Fatalf("cannot create pseudo procfs process directory, reason: %s",
				err.Error())
		}
	}

	f := func(fn func(b *testing.B, tmpdir string)) func(*testing.B) {
		return func(b *testing.B) {
			fn(b, testdatadir)
		}
	}
	b.Run("os.ReadDir", f(bmOsReadDir))
	b.Run("os.File.ReadDir", f(bmFileReadDir))
}
```

This creates the temporary directory entries only once per benchmark run and we
thus run the real individual benchmarks as sub-benchmarks of `BenchmarkReadDir`.

> [!NOTE] A benchmark that calls Run at least once will not be measured itself
> and will be called once with N=1.[^testing]

For starters, let's benchmark with a small number of directory entries of 16
(which should mimic the many smaller directories inside `procfs` very well).
Also, benchmark with only one, two, or four CPUs to see what if any effects this
might yield (pun intended).

```bash
taskset -c 24-31 \
	go test -bench='ReadDir/os\..*ReadDir' -run=^$ \
		-cpu=1,2,4 -benchmem -benchtime=10s -dir-entries=16
```

The results:

```text
goos: linux
goarch: amd64
pkg: github.com/thediveo/faf
cpu: AMD Ryzen 9 7950X 16-Core Processor            
BenchmarkReadDir/os.ReadDir              1996620              5957 ns/op            1718 B/op         32 allocs/op
BenchmarkReadDir/os.ReadDir-2            2126792              5640 ns/op            1718 B/op         32 allocs/op
BenchmarkReadDir/os.ReadDir-4            2135574              5630 ns/op            1719 B/op         32 allocs/op
BenchmarkReadDir/os.File.ReadDir         1918167              6254 ns/op            1718 B/op         32 allocs/op
BenchmarkReadDir/os.File.ReadDir-2       1975518              6079 ns/op            1718 B/op         32 allocs/op
BenchmarkReadDir/os.File.ReadDir-4       1986109              6055 ns/op            1720 B/op         32 allocs/op
```

First, running the benchmark on more than two CPUs doesn't give any real bost,
which is to be expected as this is all happens without invoking additional go
routines. This said, there still is a noticeable improvement in using a _second_
CPU: probably so that the Go runtime can do some things concurrently with the
branchmarking CPU. In the following, we thus focus on the two CPU benchmarks
only.

But wait ... _WHAT_?!!

Leaving out the sort makes reading directories **slower**? Did we just manage to
write a Time Machine in Go? The ns/op difference between `os.ReadDir-2` and our
pure `os.File.ReadDir-2` version are roughly 8%.

So let's benchmark with a larger number of directory entries, such as 1024:

```bash
taskset -c 24-31 \
	go test -bench='ReadDir/os\..*ReadDir' -run=^$ \
		-cpu=2 -benchmem -benchtime=10s -dir-entries=1024
```

```text
BenchmarkReadDir/os.ReadDir-2              52171            231244 ns/op          128719 B/op       2055 allocs/op
BenchmarkReadDir/os.File.ReadDir-2         75919            157559 ns/op          128658 B/op       2055 allocs/op
```

Sadly, `Sort` cannot be used as a time machine; but where does the overhead in
`os.File.ReadDir` come from?

### Down the Gopher Hole

So we need to dig into the std library in hope of turning up some explanation
for these counter-intuitive benchmark results. What does
[`os.ReadDir`](https://cs.opensource.google/go/go/+/refs/tags/go1.23.4:src/os/dir.go;l=118)
actually _do_?

```go
package os

func ReadDir(name string) ([]DirEntry, error) {
	f, err := openDir(name)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	dirs, err := f.ReadDir(-1)
	slices.SortFunc(dirs, func(a, b DirEntry) int {
		return bytealg.CompareString(a.Name(), b.Name())
	})
	return dirs, err
}
```

While one might expect a call to `os.Open` the stdlib actually calls an internal
[`os.openDir`](https://cs.opensource.google/go/go/+/refs/tags/go1.23.4:src/os/file.go;l=394)
instead. But this surely can't make a difference, innit?

```go
package os
// openDir opens a file which is assumed to be a directory. As such, it skips
// the syscalls that make the file descriptor non-blocking as these take time
// and will fail on file descriptors for directories.
func openDir(name string) (*File, error) {
	testlog.Open(name)
	return openDirNolog(name)
}
```

You're kidding, right ... _right_?

If this is the case, then how can we avoid this penalty, as `os.File.ReadDir` in
fact goes through the syscalls `openDir` alludes to? The closest approximation
without resorting to dirty linkname tactics[^linkname] might hopefully leverage
`unix.Open` plus [`os.NewFile`](https://pkg.go.dev/os#NewFile) for good
&#x2a;_cough_&#x2a; measure:

```go
func bmNewFile(b *testing.B, testdatadir string) {
	for n := 0; n < b.N; n++ {
		fd, err := unix.Open(testdatadir, unix.O_RDONLY, 0)
		if err != nil {
			b.Fatalf("cannot open directory, reason: %s", err)
		}
		dir := os.NewFile(uintptr(fd), testdatadir)
		direntries, err = dir.ReadDir(-1)
		dir.Close()
		if err != nil {
			b.Fatalf("cannot read directory, reason: %s", err)
		}
	}
}
```

Probably more by sheer luck than any reason this hat trick brings us back to
square one – and even slightly ahead of it; even for a small number of 16 directory
entries we're now about 6% faster.

```bash
taskset -c 24-31 \
	go test -bench='ReadDir/(os\.ReadDir|os\.NewFile)' -run=^$ \
		-cpu=2 -benchmem -benchtime=10s -dir-entries=16
```

```text
BenchmarkReadDir/os.ReadDir-2            2125924              5636 ns/op            1719 B/op         32 allocs/op
BenchmarkReadDir/os.NewFile-2            2259210              5317 ns/op            1718 B/op         32 allocs/op
```

Yet still way _too many_ heap allocation, me thinks.

## Don't Lay Waste to Syscalls and Heap

For `io.ReadDir` (and our own attempts so far) the number of allocations and the
mount of heap memory needed depends on the number of directory entries
_returned_. Of course, when reading only a directory once in a while, any
optimization is pure overachievement. But when reading large numbers of
directories in the various parts of the Linux `procfs` and `sysfs`, things might
add up considerably.

### Reading Directories the Dir-ect Way

How are we supposed to read directories on Linux? Diving into Go's std library,
we find that [`os.ReadDir`](https://pkg.go.dev/os#ReadDir) →
[`os.File.ReadDir`](https://pkg.go.dev/os#File.ReadDir) →
[`os.File.readdir`](https://cs.opensource.google/go/go/+/refs/tags/go1.23.4:src/os/dir_unix.go;l=47)
(with `readdirDirEntry` mode). Now `readdir` is where things start to get both
more concrete as well as interesting: →
[`internal/poll.FD.ReadDirent`](https://cs.opensource.google/go/go/+/refs/tags/go1.23.4:src/internal/poll/fd_unixjs.go;l=52;bpv=0;bpt=0)
basically wrapping →
[`syscall.ReadDirent`](https://pkg.go.dev/syscall#ReadDirent).

On Linux, the Go standard library wires the
[`ReadDirent`](https://cs.opensource.google/go/go/+/refs/tags/go1.23.4:src/syscall/syscall_linux.go;l=1001)
syscall to use the
[`Getdents`](https://cs.opensource.google/go/go/+/refs/tags/go1.23.4:src/syscall/zsyscall_linux_amd64.go;l=472)
syscall instead, and that finally goes into the actual Linux
[getdents64(2)](https://man7.org/linux/man-pages/man2/getdents.2.html) syscall.
This way, it correctly handles large filesystems and large file offsets. At this
low level, directory entries are variable length, so some `unsafe` shenanigans
will be later required. What we get here:

- inode number
- file name
- file type: exactly one of block device, character device, directory, named
  pipe, symbolic link, unix domain socket, (gasp) a regular file, or an unknown
  file type.

Next, this low-level information is transformed by
[`os.newUnixDirent`](https://cs.opensource.google/go/go/+/refs/tags/go1.23.4:src/os/file_unix.go;l=494;bpv=0;bpt=0),
getting additional information using [os.Lstat](https://pkg.go.dev/os#Lstat).
And `Lstat` has its `FileInfo` (more precisely, `fileStat`) escaping to the heap.

### Pool Parties

When reading the directory entries, Go's std library uses a
[`sync.Pool`](https://pkg.go.dev/sync#Pool) to reuse the buffers needed for this
operation, before extracting the contained data into new objects. These buffers
are of fixed and uniform size. See
[`os.dirBufPool`](https://cs.opensource.google/go/go/+/refs/tags/go1.23.4:src/os/dir_unix.go;l=32)
for implementation details; we here use the same buffer size of 8192 octets that
Go arrived at over time.

### `string` Isn't Exactly `[]byte`

Admittedly, it took me a long time to finally grok the important difference
between `string` and `[]byte`:

> [!QUOTE] In Go, a string is in effect a read-only slice of
> bytes.[^goblogstrings]

Notice the crucial **read-only** here, otherwise known as "immutable". In
contrast, `[]byte` is a **mutable** slice of bytes. Why does this matter?
Because of ... conversions!

Consider that we've just read a directory entry into a `[]byte` buffer and this
entry contains the name of the entry. The friendly Gopher lend us a helping hand
and let us "directly" convert a part of the buffer into a `string`. But as the
resulting `string` must be immutable, yet the buffer isn't, the string contents
must be copied from the buffer in order to ensure its immutability. And if the
escape analysis is inconclusive, the Go compiler places the immutable copy on
the heap.

Please note that the Go compiler handles several optimizations where a deep copy
isn't necessary when converting between `[]byte` and `string`. However, these
are limited cases (which are still highly useful).

### Lazy Conversions

The existing `fs.DirEntry` type is an interface where we can safely assume that
fulfilling values don't fit into the interface value itself. And good strings go
to the heap, while bad strings stay in their `[]byte` buffers.

```go
package fs

type DirEntry interface {
	Name() string
	IsDir() bool
	Type() FileMode
	Info() (FileInfo, error)
}
```

The "fulfilling" type is the unexported `os.unixDirent`.

```go
package os

type unixDirent struct {
	parent string
	name   string
	typ    FileMode
	info   FileInfo
}
```

If all we need is the name and type of directory entry, but not the other
information, then we better go with our own `faf.DirEntry` that can be easily
pushed to a yield function (loop body), under the constraint that the pushed
`DirEntry` is valid only within the yield function call, but not after it has
returned.

```go
package faf

type DirEntryType uint8

type DirEntry struct {
	Ino  uint64
	Name []byte
	Type DirEntryType
}
```

Please note that we define `Name` as `[]byte` and not `string`: this way, we
avoid a costly copy to ensure an immutable name string. We leave it up to our
API user's yield function to create an immutable copy if really necessary.

## Don't Slice, Push

In my use cases, code reading directory entries then next tends to often simply
iterate over these entries, doing its work, creating the final information about
Linux resources, finally forgetting the original "low-level" directory data
anyway. A design where the iterator pushes a value that is only temporarily
valid for the duration of the called yield function should fit in nice and
snuggly.

```go
package main

for entry := range faf.ReadDir("/proc") {
	// do something with entry before it becomes invalid...
	// ...the following []byte-to-string conversion doesn't need a copy
	// as the Go compiler can optimize such usages.
	if string(entry.Name) == "cmdline" {
		// ...
	}
}
```

So let's see how the gods of benchmarking will roll their dice:

```bash
taskset -c 24-31 \
	go test -bench='ReadDir/(os|faf)\.ReadDir$' -run=^$ \
		-cpu=2 -benchmem -benchtime=10s -dir-entries=16
```

```text
BenchmarkReadDir/os.ReadDir-2            2126152              5656 ns/op            1719 B/op         32 allocs/op
BenchmarkReadDir/faf.ReadDir-2           2887299              4162 ns/op              48 B/op          1 allocs/op
```

And for 1024 entries:

```text
BenchmarkReadDir/os.ReadDir-2              51513            230204 ns/op          128716 B/op       2055 allocs/op
BenchmarkReadDir/faf.ReadDir-2            107394            111511 ns/op              48 B/op          1 allocs/op
```

With a fixed single allocation per `faf.ReadDir` we clearly succeeded in
relieving the pressure on the GC. The runtime performance benefits range from
about a quarter faster for small directories to two times as fast for larger
directories.

---

[^iter]: [iter](https://pkg.go.dev/iter) package documentation.

[^reou]: Rémy Oudompheng in [answer to "io.ioutil.ReadDir sort by
    default"](https://groups.google.com/g/golang-nuts/c/Q7hYQ9GdX9Q/m/l9WQZhPp5yEJ).

[^testing]: [testing.(*B).Run](https://pkg.go.dev/testing#B.Run) package
    documentation.

[^linkname]: ...and this Gopher hole is being plugged anyway in due time.

[^goblogstrings]: [Strings, bytes, runes and characters in Go](https://go.dev/blog/strings).
