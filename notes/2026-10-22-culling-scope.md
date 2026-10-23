# Culling Scope

## 00 -- Writing isn't that hard is it?

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
