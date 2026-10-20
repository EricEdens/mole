# Setting up the project

## 00 -- why we're here, observations

Well it's probably a good time to reflect on why we're here.

The goal, of course, is the file explorer. And _structured storage_
is important for old office documents but also modern installers. If you don't
have an MS-CFB reader, then you depend on 'file' or something like that and,
then, well, you have decades old code to maintain.

So that's the choice. Read the format.

A question though is why write a new one. The first reason is practical:
I'd like to use Zig, and there isn't an incumbent that I can find. The other
options are a bit hairy, eg C-abi over to a rust, cpp, or c library. It's
similar to the reason of avoiding 'file'. But if there were a strong zig library
then I think I'd be less worried.

Also, from reading other projects, it's a bit unclear what _their_ goal is. Part
of that is I haven't spent sufficient time reading their docs. There are quite a
few libraries. But I did around of differentials a while back, and they all had
wildly different behavior from each other, and from Windows.
Rust's [cfb](https://docs.rs/cfb/latest/cfb/) was far stricter than Windows, but
it was uncrashable. And when it parsed a file it was darn fast. So, it's kind of
that Rust mantra of safe and fast.

## 01 -- observations from setting this up

In the last few commits I setup the facade of what MS's stg offers, minus the
transaction part which I hope we don't need. Here are my observations and where
I think we'll need to push next.

### The stream quest

First, I don't know that we have to keep the distinction between
[ILockBytes](https://learn.microsoft.com/en-us/windows/win32/api/objidl/nn-objidl-ilockbytes)
and [IStream](https://learn.microsoft.com/en-us/windows/win32/api/objidl/nn-objidl-istream)
that Microsoft has. I haven't torn it out yet but I'm open to thinking about it.

I made a table of the two. The only meaningful difference is that IStream
doesn't expose flushing. The other differences are API style (cursor vs pos) and
stuff in the locks and transactions that I won't be messing with.

| Method       | IStream | ILock |
|--------------|:-------:|:-----:|
| SetSize      |    +    |   +   |
| Stat         |    +    |   +   |
| Seek         |    +    |       |
| Read         |    +    |       |
| Write        |    +    |       |
| Flush        |         |   +   |
| ReadAt       |         |   +   |
| WriteAt      |         |   +   |
| LockRegion   |    +    |   +   |
| UnlockRegion |    +    |   +   |
| Commit       |    +    |       |
| Revert       |    +    |       |
| Clone        |    +    |       |
| CopyTo       |    +    |       |

**Decision:** Let's just make it Bytes. Or Stream. Whatever the name, one thing.

### Is Storage abstract

The structured storage API gives you three entrances that I'm aware of:

1. Open a file (by name)
2. Sit on top of ILockBytes
3. Nested via a child storage

The third one I was reminded by when setting up Storage.zig. I had hoped we
could make a dumb struct over `Bytes` and move on.

Pros/cons time.

**Arguments for concrete**

* Obv I started here since it was cleaner and easier. I haven't benchmarked
  anything, but I'd presume that the vtable indirection is either negligible or
  devirtualized. I'm not worried about performance in other words.

**Arguments for vtable**

* We need something for indirection. If there's a nested excel table, then I
  want to just open a storage and hand it off. I don't want that excel parser to
  know or care whether whether it's the root or not.
* You get the sense that this is what MS had to do, given they have one
  initializer for each thing it's sitting on.
* It might make differential testing easier, if I wanted to put other software
  behind this zig api. But the real objidl.h is not that much harder for me to
  satisfy.
* It makes it easy to inject fakes and faults.

**Arguments for sealed union**

* The common perf choice, but honestly, I'd bet that it doesn't matter here. I'm
  not worried in other words.
* I've heard that it's easier, but in my experience it ends up being a mess and
  you have to wait for the compiler to yell at you.

**Decision:** vtable it is. I want fakes here, and maybe even in other packages
that do format-specific parsing. 