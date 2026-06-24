// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly

// Keywords and operators, from docs/syntax.md.
export const keywords = [
  ['let', 'Declare a variable'],
  ['const', 'Declare a binding that is meant to stay fixed (reassignment is not rejected yet)'],
  ['func', 'Define a function'],
  ['return', 'Leave a function with a value; the value must start on the same line'],
  ['if', 'else'],
  ['while', 'Loop while a boolean condition holds'],
  ['for', 'C-style loop, or for (let x in list)'],
  ['in', 'Only a keyword inside for-in; an ordinary name elsewhere'],
  ['switch', 'case, default; no fall-through; break leaves the switch'],
  ['break', 'Leave the nearest loop or switch'],
  ['continue', 'Next iteration'],
  ['use', 'Bring in a module: use "file.zu" or use { name } from "file.zu"'],
  ['from', 'Only a keyword inside use; an ordinary name elsewhere'],
  ['export', 'Make a name visible to importers (func, const, template, bloc, data; never let)'],
  ['import', 'The older spelling of use "file.zu"'],
  ['data', 'A map with a constructor. A keyword only in data Name { ... }'],
  ['template', 'A mutable record checked against its schema'],
  ['bloc', 'A small immutable value, at most 64 bytes'],
  ['box', 'A byte buffer with an owner: box[16]'],
  ['unsafe', 'A block with manual memory and ten rules'],
  ['and  or  not', 'Logical operators, short-circuit. && || ! are the same'],
  ['true  false  null', 'The boolean and null literals']
];

export const operators = [
  ['Arithmetic', '+ - * / %  and unary -', 'Int with int stays int; any float makes a float. / truncates toward zero for ints. % takes the sign of the left side'],
  ['Power', '**', 'Same as pow. Right-associative: 2 ** 3 ** 2 is 512. An int to a negative int power is an Argument Error'],
  ['Bitwise', '& | ^ << >> ~', 'Ints only. Tighter than comparisons, unlike C. A shift count is 0 to 63'],
  ['Comparison', '== != < <= > >=', '== and != need the same kind of value (1 == 1.0 is true). null compares with anything. Two lists or maps are equal only when they are the same object'],
  ['Logical', 'and / &&  or / ||  not / !', 'Operands must be booleans'],
  ['Assignment', '= += -= *= /= %= ++ --', 'x++ gives the old value, ++x the new one'],
  ['Slice and index', 'x[i]  x[a:b]  x.name', 'Slices count from 0 and include both ends. Negative indexes count from the end; negative slice positions are errors']
];

export const precedence = 'From loosest to tightest: or, and, == !=, < <= > >=, |, ^, &, << >>, + -, * / %, then ** and the unary operators.';
