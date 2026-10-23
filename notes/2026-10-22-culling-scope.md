# Culling Scope

## 00 -- Writing CFB files isn't that hard is it?

No updates from yesterday. I was too forlorn looking at the CFB file produced
by Win11 and imagining having to produce it ourselves and safely allowing
mutation of the file.

So, for now, let's cut the problem in half.

To focus back on just getting reading working (that's what desktop search is
all about, right?), I dropped the 'writeAt' shenanigans and renamed our
Buffer to Source. The API is shy enough that we can lazily read files in the
future. For now, we just read the whole thing at once.

So what's the plan for today?

First, gut the Cfb.zig that was sitting in the half-zombie state of "shoot, do
we need to edit files?". And gut the IStorage and IStream business. Maybe
that means we have to change the repo's name :).

From there, Cfb.zig: the plan is to make it a mechanical sector-based reader.
You could write a dump CLI on it, or also write a zig Io.Reader. Or the
IStream/ISource.

Back to the studs as they say.

## 01 -- Tighter foundation

I'm a lot happier with where we landed. One abstraction now, Source, that
is a sealed union that allows random access into a byte source that may
or may not be contiguous. Nothing depends on it being a sealed union, and
the only two functions are 'getSize' and 'readAt'.

CFB has another dent taken out -- we can walk the Difat, and we have a big
MS-CFB file that requires two DIFAT sectors. Still pending are: FAT, 
MINIFAT, and the directory system.

I don't like how these damn zig files end up having different casing.

`header` vs `Name` vs `source`. What does the first-letter up mean? That it's
a vanilla Zig struct? Tootaly doo.

Rant done.

I'll be happy with this CFB layer if it ends up being a lower-level 
sector based API over which we can trivially wrap it.

## 02 -- So what did we learn about setting up a package

I don't think it's bad that we started with a big scope and cut back. We
knew, for example, that we didn't want transactions. Later, we knew that
we didn't want to write.

But this was messy.

I like what we've done with `source` in this current iteration, where it is
a single thing (`Source`) that happens to be a sealed union. It has the public
API that we want for creation, usage, and deletion. And we later can change
it to something else. vtables? why not. So, hmm, maybe we should avoid vtables
up front?  :)

I also like the `Difat` struct that we've set up. The public API is brutally
small:  `get`. But underneath, we've built this walking-on-stilts platform
of a cursor that we can hopefully emulate up all the way to the top. But,
again, we don't have to.
