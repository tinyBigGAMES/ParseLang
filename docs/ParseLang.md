# ParseLang Reference

> ParseLang™ - Describe It. Parse It. Build It.

ParseLang is the meta-language layer of the [Parse()](https://parsekit.org) toolkit. It lets you describe a complete programming language: its tokens, grammar rules, semantic analysis, and C++23 code generation, in a single `.parse` file. The Parse() toolkit reads that file, builds a live fully-configured compiler in memory, and immediately uses it to compile your source files to native binaries via Zig.

---

## Table of Contents

1. [Two-Phase Architecture](#1-two-phase-architecture)
2. [File Structure](#2-file-structure)
3. [Lexer Sections](#3-lexer-sections)
   - 3.1 [keywords](#31-keywords)
   - 3.2 [operators](#32-operators)
   - 3.3 [strings](#33-strings)
   - 3.4 [comments](#34-comments)
   - 3.5 [structural](#35-structural)
   - 3.6 [types](#36-types)
   - 3.7 [literals](#37-literals)
   - 3.8 [typemap](#38-typemap)
4. [Grammar Rules](#4-grammar-rules)
   - 4.1 [registerLiterals](#41-registerliterals)
   - 4.2 [binaryop](#42-binaryop)
   - 4.3 [prefix](#43-prefix)
   - 4.4 [infix](#44-infix)
   - 4.5 [statement](#45-statement)
   - 4.6 [exproverride](#46-exproverride)
5. [Semantic Rules](#5-semantic-rules)
6. [Emit Rules](#6-emit-rules)
7. [Helper Functions](#7-helper-functions)
8. [The Scripting Language](#8-the-scripting-language)
   - 8.1 [Variables and Assignment](#81-variables-and-assignment)
   - 8.2 [Control Flow](#82-control-flow)
   - 8.3 [Expressions](#83-expressions)
   - 8.4 [Field Access](#84-field-access)
   - 8.5 [Implicit Variables by Context](#85-implicit-variables-by-context)
9. [Built-in Functions](#9-built-in-functions)
   - 9.1 [Common: all contexts](#91-common-all-contexts)
   - 9.2 [Parse context](#92-parse-context)
   - 9.3 [Semantic context](#93-semantic-context)
   - 9.4 [Emit context](#94-emit-context)
10. [Pipeline Configuration](#10-pipeline-configuration)
11. [Using TParseLang from Delphi](#11-using-tparselang-from-delphi)
12. [Token Kind Naming Conventions](#12-token-kind-naming-conventions)
13. [Node Kind Naming Conventions](#13-node-kind-naming-conventions)

---

## 1. Two-Phase Architecture

A `.parse` file is processed in two sequential phases.

**Phase 1: Bootstrap compilation**

The `.parse` file is compiled by the ParseLang bootstrap parser. The result is a live `TParse` instance fully configured with your language's lexer, grammar, semantic rules, and emitters. All closures registered during this phase capture references to AST nodes that belong to the bootstrap parse instance.

**Phase 2: Source compilation**

The configured `TParse` instance compiles your source file: lexing, parsing, semantic analysis, C++23 code generation, and Zig native compilation. The bootstrap instance must remain alive for the entire duration of Phase 2 because Phase 2 closures reference its AST.

```
mylang.parse  ---> ParseLang bootstrap ---> configured TParse
                                                   |
myprogram.ml  ----------------------------------> TParse.Compile()
                                                   |
                                             native binary
```

The key point: you never write Delphi code. Everything (lexer rules, Pratt parser handlers, semantic analysis, and C++23 emitters) is expressed in the `.parse` file using ParseLang's scripting blocks.

---

## 2. File Structure

A `.parse` file begins with a `language` declaration and is followed by any number of sections and rules in any order.

```
language MyLang;

-- Lexer sections
keywords   casesensitive  ...  end
operators  ...  end
strings    ...  end
comments   ...  end
structural ...  end
types      ...  end
literals   ...  end
typemap    ...  end

-- Grammar rules
registerLiterals;
binaryop 'tok' power N op 'cppop';
prefix    'tok' as 'node'  parse ... end  end
infix     left 'tok' power N as 'node'  parse ... end  end
statement 'tok' as 'node'  parse ... end  end
exproverride 'node'  override ... end  end

-- Semantic and emit
semantic 'node.kind'  ...  end
emit     'node.kind'  ...  end

-- Reusable helpers
function name(param: type, ...) -> type  ...  end
```

Comments use `--` (line only). Statements are terminated with `;`. All blocks close with `end`.

---

## 3. Lexer Sections

### 3.1 keywords

Declares reserved words. The lexer recognises these and emits the given token kind string instead of `identifier`. The optional modifier `casesensitive` or `caseinsensitive` controls matching. Default is `caseinsensitive`.

```
keywords casesensitive
  'var'    -> 'keyword.var';
  'func'   -> 'keyword.func';
  'return' -> 'keyword.return';
  'if'     -> 'keyword.if';
  'then'   -> 'keyword.then';
  'else'   -> 'keyword.else';
  'while'  -> 'keyword.while';
  'do'     -> 'keyword.do';
  'end'    -> 'keyword.end';
  'true'   -> 'keyword.true';
  'false'  -> 'keyword.false';
  'nil'    -> 'keyword.nil';
end
```

### 3.2 operators

Declares multi- and single-character operator tokens. Longer operators must appear before shorter ones to guarantee longest-match behaviour.

```
operators
  ':=' -> 'op.assign';
  '<>' -> 'op.neq';
  '<=' -> 'op.lte';
  '>=' -> 'op.gte';
  '->' -> 'op.arrow';
  '+'  -> 'op.plus';
  '-'  -> 'op.minus';
  '*'  -> 'op.star';
  '/'  -> 'op.slash';
  '%'  -> 'op.percent';
  '='  -> 'op.eq';
  '<'  -> 'op.lt';
  '>'  -> 'op.gt';
  '('  -> 'delimiter.lparen';
  ')'  -> 'delimiter.rparen';
  ','  -> 'delimiter.comma';
  ':'  -> 'delimiter.colon';
  ';'  -> 'delimiter.semicolon';
end
```

### 3.3 strings

Declares string literal styles. Each entry specifies an open delimiter, a close delimiter, a token kind, and an optional `escape` flag.

`escape true`: backslash sequences (`\n`, `\t`, `\\`, etc.) are processed inside the string.

`escape false`: content is taken literally; two consecutive close-delimiter characters represent a single literal close delimiter (Pascal style).

```
strings
  '"' '"' -> 'literal.string' escape true;
end
```

### 3.4 comments

Declares comment styles. `line` comments run from the prefix to end of line. `block` comments span multiple lines.

```
comments
  line '--';
  line '//';
  block '(*' '*)';
end
```

### 3.5 structural

Declares the three structural token kinds the parser engine uses for block-aware parsing.

- `terminator`: the statement separator/terminator token kind.
- `blockopen`: the token kind that opens a generic block.
- `blockclose`: the token kind that closes any block.

```
structural
  terminator 'delimiter.semicolon';
  blockclose 'keyword.end';
end
```

### 3.6 types

Declares type keyword tokens. These are registered separately so the semantic engine can resolve type text to type kind strings via `typeTextToKind()`.

```
types
  'int'    -> 'type.int';
  'string' -> 'type.string';
  'bool'   -> 'type.bool';
  'void'   -> 'type.void';
end
```

### 3.7 literals

Declares which AST node kinds represent literal values and what type kind they carry. Used by the semantic engine's `InferLiteralType()`.

```
literals
  'literal.integer' -> 'type.int';
  'literal.string'  -> 'type.string';
  'expr.bool'       -> 'type.bool';
end
```

### 3.8 typemap

Maps your language's type kind strings to C++ type strings. Call `typeToIR(kind)` in emit blocks to resolve them. Multiple `typemap` blocks are merged.

```
typemap
  'type.int'    -> 'int64_t';
  'type.string' -> 'std::string';
  'type.bool'   -> 'bool';
  'type.void'   -> 'void';
end
```

---

## 4. Grammar Rules

Grammar rules register handlers with the Pratt parser engine. All handler bodies are written in the [ParseLang scripting language](#8-the-scripting-language).

### 4.1 registerLiterals

Registers the framework's built-in literal prefix handlers for integer, real, string, and char token kinds. Call this once after your lexer sections.

```
registerLiterals;
```

### 4.2 binaryop

Shorthand for registering standard binary operators that map directly to a C++ infix operator. One declaration registers both the infix parse handler and the emit handler automatically.

```
binaryop 'op.plus'    power 20 op '+';
binaryop 'op.minus'   power 20 op '-';
binaryop 'op.star'    power 30 op '*';
binaryop 'op.slash'   power 30 op '/';
binaryop 'op.percent' power 30 op '%';
binaryop 'op.eq'      power 10 op '==';
binaryop 'op.neq'     power 10 op '!=';
binaryop 'op.lt'      power 10 op '<';
binaryop 'op.gt'      power 10 op '>';
binaryop 'op.lte'     power 10 op '<=';
binaryop 'op.gte'     power 10 op '>=';
```

Conventional binding power scale: comparisons 10, addition/subtraction 20, multiplication/division 30, unary 50, call/index 80-90.

### 4.3 prefix

A prefix rule fires when the parser sees the given token kind at the start of an expression. The handler must assign the created node to `result`.

The `parse` keyword opens the scripting block. The first `end` closes the scripting block; the second closes the `prefix` rule.

```
-- Grouped expression:  ( expr )
prefix 'delimiter.lparen' as 'expr.grouped'
  parse
    consume();
    result := createNode();
    addChild(result, parseExpr(0));
    expect('delimiter.rparen');
  end
end

-- Unary minus:  -expr
prefix 'op.minus' as 'expr.negate'
  parse
    result := createNode();
    consume();
    addChild(result, parseExpr(50));
  end
end

-- Boolean true literal
prefix 'keyword.true' as 'expr.bool'
  parse
    result := createNode();
    setAttr(result, 'bool.value', 'true');
    consume();
  end
end

-- Identifier reference
prefix 'identifier' as 'expr.ident'
  parse
    result := createNode();
    setAttr(result, 'ident.name', current().text);
    consume();
  end
end
```

**Implicit variables:** `result`: assign the created AST node here.

### 4.4 infix

An infix rule fires when the given token kind appears between two expressions. The already-parsed left expression is available as `left`. Set associativity with `left` or `right`. Set binding power with `power`.

```
-- Function call:  ident( arg, arg, ... )
-- Binding power 80: tighter than any binary operator.
infix left 'delimiter.lparen' power 80 as 'expr.call'
  parse
    result := createNode();
    setAttr(result, 'call.name', getAttr(left, 'ident.name'));
    consume();   -- consume '('
    if not check('delimiter.rparen') then
      addChild(result, parseExpr(0));
      while match('delimiter.comma') do
        addChild(result, parseExpr(0));
      end
    end
    expect('delimiter.rparen');
  end
end
```

**Implicit variables:** `result`: assign the created node; `left`: the already-parsed left operand.

### 4.5 statement

A statement rule fires when the given token kind appears at the start of a statement position.

```
-- var x: type := expr ;
statement 'keyword.var' as 'stmt.var_decl'
  parse
    result := createNode();
    consume();   -- 'var'
    setAttr(result, 'decl.name', current().text);
    consume();   -- identifier
    expect('delimiter.colon');
    setAttr(result, 'decl.type_text', current().text);
    consume();   -- type keyword
    expect('op.assign');
    addChild(result, parseExpr(0));
    expect('delimiter.semicolon');
  end
end

-- func name( params ) -> type stmts end
statement 'keyword.func' as 'stmt.func_decl'
  parse
    result := createNode();
    consume();   -- 'func'
    setAttr(result, 'func.name', current().text);
    consume();   -- function name
    expect('delimiter.lparen');
    while not check('delimiter.rparen') do
      param := createNode('stmt.param');
      setAttr(param, 'param.name', current().text);
      consume();
      expect('delimiter.colon');
      setAttr(param, 'param.type_text', current().text);
      consume();
      addChild(result, param);
      if not check('delimiter.rparen') then
        expect('delimiter.comma');
      end
    end
    expect('delimiter.rparen');
    if match('op.arrow') then
      setAttr(result, 'func.return_type_text', current().text);
      consume();
    else
      setAttr(result, 'func.return_type_text', 'void');
    end
    funcBody := createNode('stmt.block');
    while not check('keyword.end') do
      addChild(funcBody, parseStmt());
    end
    addChild(result, funcBody);
    expect('keyword.end');
  end
end
```

**Implicit variables:** `result`: assign the created AST node here.

### 4.6 exproverride

Overrides how a specific node kind is rendered to a C++ expression string by `exprToString()`. Use this when the default rendering is insufficient for a custom node kind.

```
-- expr.negate is a custom node kind the framework does not know about.
-- Override its rendering here.
exproverride 'expr.negate'
  override
    result := '-' + exprToString(getChild(node, 0));
  end
end
```

**Implicit variables:** `node`: the AST node being rendered; `result`: assign the C++ expression string.

Call `default(node)` inside an override block to invoke the framework's default renderer for sub-expressions.

---

## 5. Semantic Rules

Semantic rules fire during the semantic analysis pass when a node of the given kind is visited. Use them to manage scope, declare and resolve symbols, record type information, and report errors.

```
semantic 'program.root'
  pushScope('global', node);
  visitChildren(node);
  popScope(node);
end

semantic 'stmt.func_decl'
  declare(getAttr(node, 'func.name'), node);
  pushScope(getAttr(node, 'func.name'), node);
  i := 0;
  while i < childCount(node) - 1 do
    visitNode(getChild(node, i));
    i := i + 1;
  end
  visitNode(getChild(node, childCount(node) - 1));
  popScope(node);
end

semantic 'stmt.var_decl'
  ok := declare(getAttr(node, 'decl.name'), node);
  if not ok then
    error(node, 'ML001', 'Duplicate variable: ' + getAttr(node, 'decl.name'));
  end
  setAttr(node, 'sem.type', typeTextToKind(getAttr(node, 'decl.type_text')));
  visitChildren(node);
end

semantic 'expr.ident'
  sym := lookup(getAttr(node, 'ident.name'));
  if sym = nil then
    error(node, 'ML003', 'Undeclared identifier: ' + getAttr(node, 'ident.name'));
  end
end
```

**Structure:**
```
semantic '<node-kind>'
  -- node: the AST node being analysed
  -- no result variable needed
end
```

Node kinds not covered by a semantic rule are walked transparently: their children are visited automatically without any handler required.

---

## 6. Emit Rules

Emit rules fire during code generation when a node of the given kind is walked. Statement nodes call IR builder procedures directly. Expression nodes assign their C++ text to `result`.

```
emit 'program.root'
  setPlatform('win64');
  setBuildMode('exe');
  setOptimize('debug');
  include('cstdint', target.header);
  include('cstdio',  target.header);
  include('string',  target.header);
  -- First pass: emit function declarations
  i := 0;
  while i < childCount(node) do
    child := getChild(node, i);
    if nodeKind(child) = 'stmt.func_decl' then
      emitNode(child);
    end
    i := i + 1;
  end
  -- Second pass: emit main body
  func('main', 'int');
  i := 0;
  while i < childCount(node) do
    child := getChild(node, i);
    if nodeKind(child) <> 'stmt.func_decl' then
      emitNode(child);
    end
    i := i + 1;
  end
  returnVal('0');
  endFunc();
end

emit 'stmt.var_decl'
  declVar(getAttr(node, 'decl.name'),
          resolveType(getAttr(node, 'decl.type_text')),
          exprToString(getChild(node, 0)));
end

emit 'stmt.if'
  cond := exprToString(getChild(node, 0));
  ifStmt(cond);
  emitBlock(getChild(node, 1));
  if childCount(node) > 2 then
    elseStmt();
    emitBlock(getChild(node, 2));
  end
  endIf();
end

emit 'stmt.while'
  cond := exprToString(getChild(node, 0));
  whileStmt(cond);
  emitBlock(getChild(node, 1));
  endWhile();
end

emit 'stmt.return'
  if childCount(node) > 0 then
    returnVal(exprToString(getChild(node, 0)));
  else
    returnVoid();
  end
end

emit 'expr.call'
  fname := getAttr(node, 'call.name');
  args := '';
  i := 0;
  while i < childCount(node) do
    if i > 0 then
      args := args + ', ';
    end
    args := args + exprToString(getChild(node, i));
    i := i + 1;
  end
  result := fname + '(' + args + ')';
end

emit 'expr.ident'
  result := get(getAttr(node, 'ident.name'));
end

emit 'expr.grouped'
  result := '(' + exprToString(getChild(node, 0)) + ')';
end

emit 'expr.bool'
  result := getAttr(node, 'bool.value');
end

emit 'expr.nil'
  result := nullLit();
end
```

**Structure:**
```
emit '<node-kind>'
  -- node: the AST node being emitted
  -- result: assign C++23 expression text here (expression nodes only)
end
```

---

## 7. Helper Functions

Helper functions are reusable scripting routines callable from any parse, semantic, emit, or exproverride block.

**Parameter types are enforced at call time.** Passing the wrong number of arguments reports error `PL001` and stops execution. Passing an argument of the wrong type reports error `PL002` and stops execution.

```
function resolveType(typeText: string) -> string
  result := typeToIR(typeTextToKind(typeText));
end

function emitBlock(blk: node)
  i := 0;
  while i < childCount(blk) do
    emitNode(getChild(blk, i));
    i := i + 1;
  end
end
```

**Structure:**
```
function <n>(<param>: <type>, ...) [-> <return-type>]
  -- body
  -- assign result to return a value
end
```

**Parameter types:** `string`, `int`, `bool`, `node`, `token`.

**Return type:** if specified, the caller receives the value of `result` at function end. If omitted, the function is void and returns nil.

Helper functions are called exactly like built-ins:

```
emit 'stmt.var_decl'
  declVar(getAttr(node, 'decl.name'),
          resolveType(getAttr(node, 'decl.type_text')),
          exprToString(getChild(node, 0)));
end
```

---

## 8. The Scripting Language

The scripting language is used inside `parse`, `semantic`, `emit`, `override`, and `function` bodies.

### 8.1 Variables and Assignment

Variables are declared implicitly on first assignment. There is no explicit `var` declaration inside scripting blocks.

```
x := 42;
name := 'hello';
ok := true;
n := createNode();
```

### 8.2 Control Flow

**if / else if / else / end**

```
if x > 10 then
  emitLine('big');
else if x > 5 then
  emitLine('medium');
else
  emitLine('small');
end
```

**while / do / end**

```
i := 0;
while i < childCount(node) do
  emitNode(getChild(node, i));
  i := i + 1;
end
```

**for / in / do / end**

Iterates from `0` to `N-1` where `N` is the integer value of the range expression.

```
for i in childCount(node) do
  emitNode(getChild(node, i));
end
```

**repeat / until**

```
repeat
  tok := consume();
until tok.kind = 'delimiter.semicolon';
```

### 8.3 Expressions

| Expression | Example |
|---|---|
| Integer literal | `42` |
| String literal | `'hello world'` |
| Boolean literal | `true`, `false` |
| Nil | `nil` |
| Variable | `x` |
| Field access | `node.token`, `tok.text`, `tok.kind` |
| Array index | `s[1]` (1-based) |
| Function call | `foo(a, b)` |
| Grouped | `(x + y)` |
| Arithmetic | `+` `-` `*` |
| Comparison | `=` `<>` `<` `>` `<=` `>=` |
| Logical | `and` `or` `not` |
| String concat | `'hello' + ' ' + name` |

### 8.4 Field Access

| Value | Field | Result |
|---|---|---|
| `node` | `.token` | The node's source token (type: token) |
| `token` | `.text` | Raw source text (string) |
| `token` | `.kind` | Token kind string (string) |
| `target` | `.source` | `sfSource` sentinel for IR calls |
| `target` | `.header` | `sfHeader` sentinel for IR calls |

### 8.5 Implicit Variables by Context

| Context | Variable | Type | Description |
|---|---|---|---|
| `prefix` / `statement` | `result` | node | Assign the created AST node here |
| `infix` | `result` | node | Assign the created AST node here |
| `infix` | `left` | node | The already-parsed left operand |
| `semantic` | `node` | node | The AST node being analysed |
| `emit` | `node` | node | The AST node being emitted |
| `emit` | `result` | string | Assign C++23 expression text here |
| `emit` | `target` | sentinel | Use `.source` / `.header` for IR target |
| `exproverride` | `node` | node | The AST node being rendered |
| `exproverride` | `result` | string | Assign the C++ expression text |

---

## 9. Built-in Functions

### 9.1 Common: all contexts

Available in every scripting block.

| Function | Returns | Description |
|---|---|---|
| `nodeKind(node)` | string | Get the kind string of a node |
| `getAttr(node, key)` | string | Read a string attribute from a node |
| `setAttr(node, key, value)` | | Write a string attribute onto a node |
| `getChild(node, index)` | node | Get child node at zero-based index |
| `childCount(node)` | int | Number of children of a node |
| `len(s)` | int | Length of string `s` |
| `substr(s, start, count)` | string | Substring (1-based start) |
| `replace(s, find, repl)` | string | Replace all occurrences in `s` |
| `uppercase(s)` | string | Convert string to upper case |
| `lowercase(s)` | string | Convert string to lower case |
| `trim(s)` | string | Strip leading and trailing whitespace |
| `strtoint(s)` | int | Parse string to integer (0 on failure) |
| `inttostr(n)` | string | Convert integer to string |
| `format(fmt, ...)` | string | Printf-style formatting (`%s`, `%d`) |
| `typeTextToKind(text)` | string | Resolve type keyword text to type kind string |

### 9.2 Parse context

Available inside `prefix`, `infix`, and `statement` parse blocks.

| Function | Returns | Description |
|---|---|---|
| `createNode()` | node | Create node with the rule's node kind and current token |
| `createNode(kind)` | node | Create node with explicit kind and current token |
| `createNode(kind, tok)` | node | Create node with explicit kind and explicit token |
| `addChild(parent, child)` | | Append child node to parent |
| `consume()` | token | Consume current token and advance |
| `expect(kind)` | | Assert current token is `kind` and consume it |
| `check(kind)` | bool | True if current token is `kind` (no consume) |
| `match(kind)` | bool | Consume and return true if current token is `kind` |
| `current()` | token | Current token (not consumed) |
| `peek()` | token | Next token (lookahead, not consumed) |
| `parseExpr(power)` | node | Parse an expression with minimum binding power |
| `parseStmt()` | node | Parse the next statement |
| `bindPower()` | int | Binding power of the current infix token |
| `bindPowerRight()` | int | Right binding power of the current infix token |
| `blockCloseKind()` | string | The configured block-close token kind |
| `stmtTermKind()` | string | The configured statement terminator kind |

### 9.3 Semantic context

Available inside `semantic` blocks.

| Function | Returns | Description |
|---|---|---|
| `pushScope(name, node)` | | Push a named scope |
| `popScope(node)` | | Pop the current scope |
| `visitNode(node)` | | Dispatch the semantic handler for a node |
| `visitChildren(node)` | | Visit all children of a node |
| `declare(name, node)` | bool | Declare a symbol; returns false if duplicate |
| `lookup(name)` | node/nil | Look up a symbol through the full scope chain |
| `lookupLocal(name)` | node/nil | Look up a symbol in the current scope only |
| `insideRoutine()` | bool | True if currently inside a function or procedure scope |
| `error(node, code, msg)` | | Report a semantic error |
| `warn(node, code, msg)` | | Report a semantic warning |
| `typeTextToKind(text)` | string | Resolve type text to type kind string |

### 9.4 Emit context

Available inside `emit` and `exproverride` blocks.

**Low-level output:**

| Function | Description |
|---|---|
| `emitLine(text)` | Emit an indented line with newline to source file |
| `emitLine(text, target.header)` | Emit to header file instead |
| `emitLine(fmt, arg1, ...)` | Formatted emit (`%s`, `%d`) |
| `emit(text)` | Emit text verbatim (no indent, no newline) |
| `emitRaw(text)` | Emit truly verbatim (no processing) |
| `indentIn()` | Increase indentation level |
| `indentOut()` | Decrease indentation level |
| `emitNode(node)` | Dispatch the emit handler for a node |
| `emitChildren(node)` | Emit all children of a node |
| `blankLine()` | Emit a blank line |

**Function builder (call in sequence):**

| Function | C++ output |
|---|---|
| `func(name, returnType)` | Opens: `returnType name(` |
| `param(name, type)` | Adds parameter to signature |
| `endFunc()` | Closes: `}` |

**Declarations:**

| Function | C++ output |
|---|---|
| `include(name)` | `#include <name>` in header |
| `include(name, target.source)` | `#include <name>` in source |
| `struct(name)` | `struct name {` |
| `addField(name, type)` | `type name;` inside struct |
| `endStruct()` | `};` |
| `declConst(name, type, value)` | `constexpr auto name = value;` |
| `global(name, type, init)` | `static type name = init;` |
| `usingAlias(alias, original)` | `using alias = original;` |
| `namespace(name)` | `namespace name {` |
| `endNamespace()` | `}` |

**Statements:**

| Function | C++ output |
|---|---|
| `declVar(name, type)` | `type name;` |
| `declVar(name, type, init)` | `type name = init;` |
| `assign(lhs, expr)` | `lhs = expr;` |
| `stmt(text)` | `text;` |
| `returnVoid()` | `return;` |
| `returnVal(expr)` | `return expr;` |
| `ifStmt(cond)` | `if (cond) {` |
| `elseIfStmt(cond)` | `} else if (cond) {` |
| `elseStmt()` | `} else {` |
| `endIf()` | `}` |
| `whileStmt(cond)` | `while (cond) {` |
| `endWhile()` | `}` |
| `forStmt(var, init, cond, step)` | `for (auto var = init; cond; step) {` |
| `endFor()` | `}` |
| `breakStmt()` | `break;` |
| `continueStmt()` | `continue;` |

**Expression builders (return C++ string fragments):**

| Function | C++ result |
|---|---|
| `lit(n)` | Integer literal e.g. `42` |
| `str(s)` | String literal e.g. `"hello"` |
| `boolLit(b)` | `true` or `false` |
| `nullLit()` | `nullptr` |
| `get(name)` | Variable reference `name` |
| `field(obj, member)` | `obj.member` |
| `deref(ptr, member)` | `ptr->member` |
| `deref(ptr)` | `*ptr` |
| `addrOf(name)` | `&name` |
| `index(arr, i)` | `arr[i]` |
| `cast(type, expr)` | `static_cast<type>(expr)` |
| `invoke(func, ...)` | `func(args...)` |
| `add(l, r)` | `l + r` |
| `sub(l, r)` | `l - r` |
| `mul(l, r)` | `l * r` |
| `divExpr(l, r)` | `l / r` |
| `modExpr(l, r)` | `l % r` |
| `neg(e)` | `-e` |
| `eq(l, r)` | `l == r` |
| `ne(l, r)` | `l != r` |
| `lt(l, r)` | `l < r` |
| `le(l, r)` | `l <= r` |
| `gt(l, r)` | `l > r` |
| `ge(l, r)` | `l >= r` |
| `andExpr(l, r)` | `l && r` |
| `orExpr(l, r)` | `l \|\| r` |
| `notExpr(e)` | `!e` |
| `bitAnd(l, r)` | `l & r` |
| `bitOr(l, r)` | `l \| r` |
| `bitXor(l, r)` | `l ^ r` |
| `bitNot(e)` | `~e` |
| `shlExpr(l, r)` | `l << r` |
| `shrExpr(l, r)` | `l >> r` |

**Type resolution:**

| Function | Returns | Description |
|---|---|---|
| `typeToIR(kind)` | string | Type kind string to C++ type (uses typemap) |
| `resolveTypeIR(text)` | string | Type text to C++ type (text -> kind -> IR) |
| `exprToString(node)` | string | Render an expression node to a C++ string |

**ExprOverride only:**

| Function | Returns | Description |
|---|---|---|
| `default(node)` | string | Invoke the framework's default expression renderer |

**Cross-handler state:**

| Function | Description |
|---|---|
| `setContext(key, value)` | Store a string value in the IR context bag |
| `getContext(key, default)` | Retrieve a string value from the IR context bag |

---

## 10. Pipeline Configuration

These built-ins are available in emit blocks and configure the Zig build pipeline. Call them from your top-level program node's emit handler, or wire them to source-level statements so user programs can declare their own build settings.

| Function | Values | Description |
|---|---|---|
| `setPlatform(p)` | `'win64'`, `'linux64'` | Target platform |
| `setBuildMode(m)` | `'exe'`, `'lib'`, `'dll'` | Output type |
| `setOptimize(o)` | `'debug'`, `'release'`, `'speed'`, `'size'` | Optimisation level |
| `setSubsystem(s)` | `'console'`, `'gui'` | Windows subsystem |
| `setOutputPath(p)` | any string | Override output directory |
| `viEnabled(v)` | `'true'`, `'false'` | Enable Windows version resource |
| `viExeIcon(path)` | file path string | Embed icon into the executable |
| `viMajor(v)` | integer string | Version major number |
| `viMinor(v)` | integer string | Version minor number |
| `viPatch(v)` | integer string | Version patch number |
| `viProductName(v)` | string | Product name in version resource |
| `viDescription(v)` | string | File description in version resource |
| `viFilename(v)` | string | Original filename in version resource |
| `viCompanyName(v)` | string | Company name in version resource |
| `viCopyright(v)` | string | Copyright string in version resource |

Caller-supplied `SetTargetPlatform()`, `SetBuildMode()`, and `SetOptimizeLevel()` values from the Delphi side are applied as defaults before Phase 1 runs. Pipeline calls in emit blocks override those defaults.

**Wiring source-level configuration:** define grammar statements for each configuration keyword and connect their emit handlers to the pipeline built-ins:

```
-- In mylang.parse

statement 'keyword.platform' as 'stmt.set_platform'
  parse
    result := createNode();
    consume();
    setAttr(result, 'pipeline.value', current().text);
    consume();
    expect('delimiter.semicolon');
  end
end

emit 'stmt.set_platform'
  setPlatform(getAttr(node, 'pipeline.value'));
end

emit 'stmt.vi_major'
  viMajor(getAttr(node, 'vi.value'));
end
```

A program in that language then declares its own build target in source:

```
-- hello.ml

platform win64;
buildmode exe;
optimize debug;
subsystem console;

viEnabled true;
viMajor 1;
viMinor 0;
viPatch 0;
viProductName "Hello";
viCopyright "Copyright 2025 ParseLang";
```

---

## 11. Using TParseLang from Delphi

Add the following units to your project's search path:

- `ParseLang.pas`
- `ParseLang.Lexer.pas`
- `ParseLang.Grammar.pas`
- `ParseLang.Semantics.pas`
- `ParseLang.CodeGen.pas`

```delphi
uses
  ParseLang;

var
  LPL: TParseLang;
begin
  LPL := TParseLang.Create();
  try
    LPL.SetLangFile('mylang.parse');
    LPL.SetSourceFile('hello.ml');
    LPL.SetOutputPath('output');

    // Delphi-side defaults (overridable from inside the source file)
    LPL.SetTargetPlatform(tpWin64);
    LPL.SetBuildMode(bmExe);
    LPL.SetOptimizeLevel(olDebug);
    LPL.SetSubsystem(stConsole);

    LPL.SetStatusCallback(
      procedure(const ALine: string; const AUserData: Pointer)
      begin
        WriteLn(ALine);
      end);

    if LPL.Compile(True, False) then
      LPL.Run()
    else
    begin
      // LPL.HasErrors() is true
      // LPL.GetErrors() returns the error collection
    end;
  finally
    LPL.Free();
  end;
end;
```

**TParseLang API:**

| Method | Description |
|---|---|
| `SetLangFile(filename)` | Path to the `.parse` language definition file |
| `SetSourceFile(filename)` | Path to the source file to compile |
| `SetOutputPath(path)` | Output directory for generated files and binary |
| `SetTargetPlatform(platform)` | Default target platform |
| `SetBuildMode(mode)` | Default build mode |
| `SetOptimizeLevel(level)` | Default optimize level |
| `SetSubsystem(subsystem)` | Windows subsystem type |
| `SetLineDirectives(enabled)` | Emit `#line` directives in generated C++ |
| `SetStatusCallback(cb, data)` | Callback for status and progress messages |
| `SetOutputCallback(cb, data)` | Callback for program output capture |
| `Compile(build, autoRun)` | Run Phase 1 + Phase 2; returns True on success |
| `Run()` | Run the last successfully compiled binary |
| `GetLastExitCode()` | Exit code from the last `Run()` call |
| `HasErrors()` | True if the last `Compile()` produced errors |
| `GetErrors()` | Error collection from the last phase that ran |
| `GetVersionStr()` | ParseLang version string |

**Build platform constants:**

| Constant | Description |
|---|---|
| `tpWin64` | Windows x64 |
| `tpLinux64` | Linux x64 (native; via WSL2 on Windows) |

**Build mode constants:**

| Constant | Description |
|---|---|
| `bmExe` | Standalone executable |
| `bmLib` | Static library |
| `bmDll` | Shared library |

**Optimize level constants:**

| Constant | Source keyword | Description |
|---|---|---|
| `olDebug` | `optimize debug;` | Fast builds, full debug info |
| `olReleaseSafe` | `optimize release;` | Optimized with safety checks |
| `olReleaseFast` | `optimize speed;` | Maximum performance |
| `olReleaseSmall` | `optimize size;` | Minimum binary size |

**Subsystem constants:**

| Constant | Description |
|---|---|
| `stConsole` | Console application |
| `stGui` | GUI application (no console window) |

---

## 12. Token Kind Naming Conventions

By convention, token kind strings follow a `category.name` pattern.

| Category | Examples |
|---|---|
| `keyword.*` | `keyword.if`, `keyword.while`, `keyword.end`, `keyword.var` |
| `op.*` | `op.plus`, `op.assign`, `op.arrow`, `op.neq` |
| `delimiter.*` | `delimiter.lparen`, `delimiter.semicolon`, `delimiter.comma` |
| `literal.*` | `literal.integer`, `literal.real`, `literal.string` |
| `type.*` | `type.int`, `type.string`, `type.bool`, `type.void` |
| `comment.*` | `comment.line`, `comment.block` |
| `identifier` | (bare, no dot) |
| `eof` | (bare, no dot) |

---

## 13. Node Kind Naming Conventions

By convention, AST node kind strings follow a `category.name` pattern.

| Category | Examples |
|---|---|
| `program.*` | `program.root` |
| `stmt.*` | `stmt.if`, `stmt.var_decl`, `stmt.assign`, `stmt.func_decl`, `stmt.return` |
| `expr.*` | `expr.ident`, `expr.call`, `expr.grouped`, `expr.negate`, `expr.bool` |
| `literal.*` | `literal.integer`, `literal.string` |

The framework uses `program.root` as the root node kind. All other node kinds are yours to define.

---

<div align="center">

**ParseLang™** - Describe It. Parse It. Build It.

Copyright © 2025-present tinyBigGAMES™ LLC
All Rights Reserved.

</div>
