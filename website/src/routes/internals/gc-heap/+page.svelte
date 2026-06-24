<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Callout from '$lib/components/Callout.svelte';
  import PageRows from '$lib/components/PageRows.svelte';
</script>

<svelte:head><title>The heap · Zue</title></svelte:head>

<LessonHead title="The heap" lead="Pages, size classes, large objects and how a pointer is recognised." />

<h2>The heap</h2>

<p>
  Small objects (up to 32752 bytes) are served from 64 KB pages. A page holds objects of one size class. There are 38 classes
  from 16 to 32752 bytes. The five largest hold 6, 5, 4, 3 and 2 objects per page. A page keeps a bump index for slots never
  handed out and a map of which slots are in use.
</p>

<PageRows size="96" slots={20} used={20} live={7} />
<PageRows size="1040" slots={12} used={9} live={4} />
<PageRows size="10920" slots={6} used={6} live={6} />

<p>
  Blue slots are live, striped slots were handed out and found dead by the last sweep, and empty slots were never handed out.
  A 96-byte page holds 682 slots, and a 10920-byte page holds 6 (the figure shows fewer, to be readable).
</p>

<h3>The 38 size classes</h3>

<p class="mono-line">
  16 32 48 64 80 96 112 128 <b>144</b> 160 192 224 256 <b>272</b> 320 384 448 512 <b>528</b> 640 768 1024 <b>1040</b> 1280 1536 2048
  <b>2064</b> 3072 4096 <b>4112</b> 6144 8192 <b>8208</b> 10920 13104 16368 21840 32752
</p>

<Callout kind="note" title="why 144, 272, 528 ...">
  <p>
    The item array of a list is always <code>16 x 2^k</code> bytes, and every request is one byte larger than asked. Without a class
    just above each of those sizes, 128 bytes became a 160-byte slot, 2048 became 3072, and 4096 became 6144. The classes in bold
    were added after the heap census showed it. A row of 8 appended ints went from 192 bytes to 176.
  </p>
</Callout>

<ul>
  <li><strong>Atomic objects</strong> (strings, doubles, byte buffers, dense list data) come from separate pages and are never scanned for pointers.</li>
  <li><strong>Large objects</strong> (over 32752 bytes) get a span of their own: whole 64 KB pages mapped with <code>mmap</code>. A freed span is cached for reuse and given back with <code>munmap</code> if no allocation used it during a whole collection.</li>
  <li><strong>Chunks.</strong> Small-object pages are cut from 2 MB chunks of anonymous memory that the kernel zeroes. Each chunk is a candidate for huge pages, which means far fewer page faults.</li>
  <li><strong>The page table.</strong> Two levels, indexed by bits 32 to 47 and 16 to 31 of the address, answer "is this word a pointer into the heap, and to which object?" with two loads. The object index inside a page comes from a multiply by a per-page reciprocal, not a division.</li>
  <li><strong>Free slots.</strong> After a sweep, the free slots of a page are the zero bytes of its used map. The allocator searches that map. The sweep does not write into dead objects; the allocator clears a slot when it hands it out.</li>
</ul>
