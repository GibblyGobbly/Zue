// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly

// A small tokenizer for Zue source. It returns HTML with one span per token class.
// The keyword and builtin lists mirror compiler/shared.zu and docs/syntax.md.

export const KEYWORDS = new Set([
  'let', 'const', 'func', 'return', 'if', 'else', 'while', 'for', 'in', 'switch', 'case', 'default',
  'break', 'continue', 'use', 'from', 'export', 'import', 'data', 'template', 'bloc', 'box', 'unsafe',
  'and', 'or', 'not', 'true', 'false', 'null',
  'balls', 'big_balls', 'shared_balls', 'grab_balls', 'if_balls', 'else_balls', 'spin_balls',
  'loop_your_balls', 'switch_balls', 'drop_balls', 'jiggle_balls'
]);

export const TYPES = new Set(['int', 'float', 'bool', 'char', 'string', 'list', 'map', 'function']);

export const BUILTIN_NAMES =
  'len str_len append list_append type int float to_string fixed to_int to_float assert input print debug range args exit system clock map_set map_get map_has map_delete map_keys map_values map_items remove find slice sort map filter reduce is_empty concat substring char_at index_of index_of_any skip_chars last_index_of contains starts_with ends_with to_upper to_lower trim trim_left trim_right replace reverse repeat pad_left pad_right split join is_digit is_alpha is_alnum is_space abs min max clamp sign pow sqrt cbrt exp ln log10 sin cos tan asin acos atan atan2 sinh cosh tanh floor ceil round trunc fract mod floor_div divmod sum mean gcd lcm isqrt lerp deg_to_rad rad_to_deg open close read read_line write file_exists remove_file flush alloc free load deref store ptr_offset ptr_add defer dense_list vec_add vec_sub vec_mul vec_div vec_mul_inline mat_mul rand srand trand shuffle tshuffle ssort shape spawn wait yield channel send recv channel_close address_of'.split(
    ' '
  );

const BUILTINS = new Set(BUILTIN_NAMES);

function esc(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function span(cls, text) {
  return `<span class="t-${cls}">${esc(text)}</span>`;
}

// A double-quoted string. A { starts an interpolation, which is highlighted as code.
function readString(src, start) {
  let i = start + 1;
  let out = '';
  let buf = '"';
  const flush = () => {
    if (buf) out += span('str', buf);
    buf = '';
  };
  while (i < src.length) {
    const c = src[i];
    if (c === '\\' && i + 1 < src.length) {
      buf += c + src[i + 1];
      i += 2;
      continue;
    }
    if (c === '{') {
      flush();
      let depth = 1;
      let j = i + 1;
      while (j < src.length && depth > 0) {
        if (src[j] === '"') {
          const inner = readString(src, j);
          j = inner.end;
          continue;
        }
        if (src[j] === '{') depth++;
        else if (src[j] === '}') depth--;
        j++;
      }
      out += span('brace', '{') + highlight(src.slice(i + 1, j - 1)) + span('brace', '}');
      i = j;
      continue;
    }
    buf += c;
    i++;
    if (c === '"') break;
  }
  flush();
  return { html: out, end: i };
}

export function highlight(src) {
  let out = '';
  let i = 0;
  const n = src.length;
  while (i < n) {
    const c = src[i];
    if (c === '#' || (c === '/' && src[i + 1] === '/')) {
      let j = src.indexOf('\n', i);
      if (j < 0) j = n;
      out += span('com', src.slice(i, j));
      i = j;
    } else if (c === '"') {
      const r = readString(src, i);
      out += r.html;
      i = r.end;
    } else if (c === "'") {
      let j = i + 1;
      if (src[j] === '\\') j += 2;
      else j += 1;
      if (src[j] === "'") j++;
      out += span('str', src.slice(i, j));
      i = j;
    } else if (/[0-9]/.test(c)) {
      const m = /^(0x[0-9a-fA-F_]+|0b[01_]+|[0-9][0-9_]*(\.[0-9_]+)?([eE][+-]?[0-9]+)?)/.exec(src.slice(i));
      out += span('num', m[0]);
      i += m[0].length;
    } else if (/[A-Za-z_]/.test(c)) {
      const m = /^[A-Za-z_][A-Za-z0-9_]*/.exec(src.slice(i));
      const w = m[0];
      const prev = src[i - 1];
      const after = src.slice(i + w.length).match(/^\s*(\()/);
      if (prev === '.') out += esc(w);
      else if (KEYWORDS.has(w)) out += span('kw', w);
      else if (after && BUILTINS.has(w)) out += span('bi', w);
      else if (after) out += span('fn', w);
      else if (TYPES.has(w) && src.slice(0, i).match(/:\s*$|<\s*$/)) out += span('ty', w);
      else if (/^[A-Z]/.test(w)) out += span('ty', w);
      else out += esc(w);
      i += w.length;
    } else {
      out += esc(c);
      i++;
    }
  }
  return out;
}
