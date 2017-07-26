# Lex

`Lex` 程序生成的称为词法分析程序(`Lexer`)。这个词法分析程序的功能是读取一串字符流，当读取的字符能匹配到一个关键字的时候就执行一个动作。一个很简单的例子如下：


```
%{
#include <stdio.h>
%}

%%
stop printf("Stop command received\n");
start printf("Start command received\n");
%%
```

第一部分，在 `%{` 和 `%}` 之间的引用头文件将会直接输出到词法分析程序 `Lexer` 中。我们需要添加这个，因为之后使用的 `printf` 函数在 `stdio.h` 中定义。

每一部分使用 `%%` 分开，所以第二部分的第一行是从关键字 `stop` 开始。输入时无论在什么时候遇到关键字 `stop`，这一行的后面部分将被执行(即 `printf` 语句)。

除了 `stop`，我们也定义了 `start`，同 `stop` 一样，在输入的时候遇到 `start`，将会执行 `start` 后面的语句。

我们再次使用 `%%` 结束这一部分。

使用下面的命令编译示例1：

```
lex example1.l
cc lex.yy.c -o example1 -ll
```

> 注意，如果你使用 `flex` 代替 `lex`，在编译的时候，你要将 `-ll` 变成 `-lfl`。`RedHat 6.x` 和 `SuSE` 需要这么做，特别是你调用 `flex` 代替 `lex`的时候！

上面的指令将会生成可执行文件 `example1`。 当你运行这个文件时，他将会等待你输入。当你输入跟我我们上面定义的关键字(`start`, `stop`)不匹配将会直接输出。 如果你输入 `stop` 它将会输出 `Stop command received`。

遇到 `EOF(^D)` 时结束。

你想了解这个程序是怎么运行的，因为我们没有定义 `main()` 函数，其实 `main()` 函数定义在 `libl(liblf)` 中，编译的时候链接进来的。

## 正则匹配

上面的示例本身没有什么用处，下面的示例同样也没有用处。它将展示我们在 `Lex` 中怎么使用正则表达式，正则表达式在后面非常重要。

示例2:

```
%{
#include <stdio.h>
%}

%%
[0123456789]+ printf("NUMBER\n");
[a-zA-Z][a-zA-Z0-9]+ printf("WORD\n");
%%
```
这个 `Lex` 文件描述了两种匹配(`tokens`)：`WORDS` 和 `NUMBERs`。正则表达式可能使人气馁，但是稍微使用一下你会发现还是比较容易理解的。下面让我们来解释 `NUMBER` 匹配：

`[0123456789]+`

这个指的是，一个或者多个 0123456789 中的字符组成的序列，也可以简写成如下方式：

`[0-9]+`

现在来看 `WORD` 匹配相关的：

`[a-zA-Z][a-zA-Z0-9]*`

匹配的第一部分是一个在 `a-z` 或者 `A-Z` 中的字符。这个开始的字符后面跟着0或者多个字符或者数字。为什么要在这使用 `*` ？ `+` 表示匹配1个或多个，但是一个 `WORD` 可能由一个已经匹配了的字符组成。所以第二部分不用匹配，所以使用了 `*`。

这种方式，我们模拟了很多编程语言的变量名必须以字符开头，但是后面可以跟数字。换句话说 `temperature1` 是一个合法的变量名，但是 `1temperature` 不是。

编译示例2，使用示例1的指令，输入一些文本。 下面是示例的会话：

```
$./example2
foo
WORD

bar
WORD

123
NUMBER

bar123
WORD

123bar
NUMBER
WORD
```

你可能想知道这些输出中空格从哪里来。原因很简单，这些空格来自输入，它没有匹配任何关键字，所以又输出了。

`Flex` 手册中有正则表达式的详细信息。尽管 `Flex` 没有完全实现 `perl` 中的正则表达式，但是许多人认为 `perl` 正则表达式手册页非常有用。

确保你不要创建一个0长度的匹配像 `[0-9]*`，你的词法分析器会疑惑会重复匹配空字符串。


## 一个更复杂的 `c` 风格的示例

假如我们想解析下面一个文件：

```
logging {
	category lame-servers { null; };
	category cname { null; };
}

zone "." {
	type hint;
	file "/etc/bind/db.root";
}
```

我们清楚看到在这个文件中有许多不同种类的标示 (`tokens`)：

- WORDs  如 `zone` 和 `type`
- FILENAMEs 如 `/etc/bind/db.root`
- QUOTEs 如""
- OBRACEs {
- EBRACEs }
- SEMICOLONs: ;

对应的 `Lex` 文件如示例3：

```
%{
#include <stdio.h>
%}

%%
[a-zA-Z][a-zA-Z0-9]*    printf("WORD ");
[a-zA-Z0-9\/.-]+        printf("FILENAME ");
\"                      printf("QUOTE ");
\{                      printf("OBRACE ");
\}                      printf("EBRACE ");
;                       printf("SEMICOLON ");
\n                      printf("\n");
[ \t]+                  /* ignore whitespace */
%%

```

当我们将上面需要解析的文件输入到 `Lex` 生成的程序中，会得到如下的结果：

```
WORD OBRACE
WORD FILENAME OBRACE WORD SEMICOLON EBRACE SEMICOLON
WORD WORD OBRACE WORD SEMICOLON EBRACE SEMICOLON
EBRACE SEMICOLON

WORD QUOTE FILENAME QUOTE OBRACE
WORD WORD SEMICOLON
WORD QUOTE FILENAME QUOTE SEMICOLON
EBRACE SEMICOLON
```

当我们比较上面的配置文件，发现我们将配置文件整洁的标记化了(`Tokenized`)。配置文件的每一部分都被匹配，然后被转化成了标示(`token`)。

这些正是我们需要的传入 `YACC` 中使用的。

## `Lex` 的功能

就像我们看到的，`Lex` 可以读去任意的输入，判断每一部分的输入是什么，这个叫做标记化(`Tokenizing`)。








