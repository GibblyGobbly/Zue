// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly

// The order of the pages. The sidebars and the previous/next links are built from these lists.
export const groups = [
  {
    "name": "Start here",
    "pages": [
      {
        "slug": "hello-world",
        "title": "Hello, World"
      },
      {
        "slug": "input-and-args",
        "title": "Input and arguments"
      },
      {
        "slug": "values",
        "title": "Values and variables"
      },
      {
        "slug": "numbers",
        "title": "Numbers"
      }
    ]
  },
  {
    "name": "Text",
    "pages": [
      {
        "slug": "strings",
        "title": "Text"
      },
      {
        "slug": "strings-search",
        "title": "Looking inside text"
      },
      {
        "slug": "strings-edit",
        "title": "Changing text"
      }
    ]
  },
  {
    "name": "Numbers",
    "pages": [
      {
        "slug": "math",
        "title": "Math functions"
      },
      {
        "slug": "math-trig-random",
        "title": "Angles and random numbers"
      },
      {
        "slug": "math-vectors",
        "title": "Lists of numbers as vectors"
      }
    ]
  },
  {
    "name": "Control flow",
    "pages": [
      {
        "slug": "decisions",
        "title": "Making decisions"
      },
      {
        "slug": "loops",
        "title": "Loops"
      },
      {
        "slug": "syntax-notes",
        "title": "Small syntax notes"
      }
    ]
  },
  {
    "name": "Functions",
    "pages": [
      {
        "slug": "functions",
        "title": "Functions"
      },
      {
        "slug": "closures",
        "title": "Closures, map, filter and reduce"
      },
      {
        "slug": "recursion",
        "title": "Recursion and defer"
      }
    ]
  },
  {
    "name": "Lists and maps",
    "pages": [
      {
        "slug": "lists",
        "title": "Lists"
      },
      {
        "slug": "sorting",
        "title": "Sorting and shuffling"
      },
      {
        "slug": "maps",
        "title": "Maps"
      }
    ]
  },
  {
    "name": "Bigger programs",
    "pages": [
      {
        "slug": "modules",
        "title": "Modules"
      },
      {
        "slug": "printing",
        "title": "Printing"
      },
      {
        "slug": "shell",
        "title": "Time, the shell and exit"
      },
      {
        "slug": "files",
        "title": "Files"
      }
    ]
  },
  {
    "name": "When something breaks",
    "pages": [
      {
        "slug": "errors",
        "title": "Reading an error"
      },
      {
        "slug": "errors-runtime",
        "title": "Errors while a program runs"
      },
      {
        "slug": "types",
        "title": "What the compiler checks"
      },
      {
        "slug": "types-annotations",
        "title": "Writing types down"
      }
    ]
  },
  {
    "name": "Your own shapes",
    "pages": [
      {
        "slug": "data-and-templates",
        "title": "data and template"
      },
      {
        "slug": "blocs",
        "title": "bloc"
      },
      {
        "slug": "boxes",
        "title": "box"
      }
    ]
  },
  {
    "name": "Going lower",
    "pages": [
      {
        "slug": "unsafe",
        "title": "unsafe"
      },
      {
        "slug": "unsafe-rules-1",
        "title": "unsafe rules 1 to 5"
      },
      {
        "slug": "unsafe-rules-2",
        "title": "unsafe rules 6 to 10"
      },
      {
        "slug": "blue-threads",
        "title": "Blue threads"
      },
      {
        "slug": "channels",
        "title": "Channels"
      },
      {
        "slug": "threads-failures",
        "title": "When threads go wrong"
      }
    ]
  }
];

export const internalGroups = [
  {
    "name": "Memory",
    "pages": [
      {
        "slug": "memory",
        "title": "Value cells"
      },
      {
        "slug": "memory-places",
        "title": "Stack, heap and limits"
      }
    ]
  },
  {
    "name": "Garbage collector",
    "pages": [
      {
        "slug": "gc",
        "title": "The garbage collector: an overview"
      },
      {
        "slug": "gc-heap",
        "title": "The heap"
      },
      {
        "slug": "gc-cycle",
        "title": "One collection cycle"
      },
      {
        "slug": "gc-pacer",
        "title": "The pacer"
      },
      {
        "slug": "gc-chunks",
        "title": "Chunks and giving memory back"
      },
      {
        "slug": "gc-measured",
        "title": "Measured results"
      },
      {
        "slug": "gc-watch",
        "title": "Watching the collector"
      },
      {
        "slug": "gc-testing",
        "title": "Testing and known limits"
      }
    ]
  },
  {
    "name": "Threads",
    "pages": [
      {
        "slug": "blue-threads",
        "title": "Blue threads: the machinery"
      },
      {
        "slug": "blue-threads-gc",
        "title": "Blue threads and the collector"
      }
    ]
  },
  {
    "name": "The compiler",
    "pages": [
      {
        "slug": "self-hosting",
        "title": "Zue written in Zue"
      },
      {
        "slug": "bootstrap",
        "title": "Building Zue from its seeds"
      }
    ]
  }
];

export const lessons = groups.flatMap((g) => g.pages.map((p) => ({ ...p, href: `/learn/${p.slug}`, group: g.name })));
export const deep = internalGroups.flatMap((g) => g.pages.map((p) => ({ ...p, href: `/internals/${p.slug}`, group: g.name })));
