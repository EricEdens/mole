# Shaping the API

## 00 -- Is Storage abstract, part 2

Yesterday I noticed that we needed `Storage` to support two cases: opening
something from scratch, and opening a nested storage item to pass to a limited
consumer. That pushed toward a vtable.

On reflection, I don't think we need a vtable yet, and there's a nice decision
matrix coming out of it. Why? We have a single backend. eg, we only support
reading MS-CFB files. We don't have a different structured storage
implementation that sits on a FS directory, a database.

The only difference between "from scratch" and "nested" is which dirfd you're
holding. The actions you'll take, and in fact the code and data, are the same in
either case.

So: This is the principle to try and let's see how far we can push it.

> Reach for a vtable when you have different structs that want to participate
  in that API. `Buffer` is a good example so far. `Stream` will expose it.
  And `ArrayListBuffer`. And probably a filesystem implementation.