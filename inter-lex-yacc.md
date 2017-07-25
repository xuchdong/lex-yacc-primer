# `Lex` 和 `YACC` 内部是怎么工作的

在 `YACC` 文件中，你写自己 `main()` 函数，调用 `yyparse()` 函数。`yyparse()` 函数被 `YACC` 创建，在 `y.tab.c` 中结束。

`yyparse()` 从 `yylex()` 中读取必须提供的 `token/value` 流。你也可以自己编写这个函数，或者让 `Lex` 为你生成。在我们的示例中，我们选择让 `Lex` 帮我们做。

`yylex()` 被 `Lex` 生成，从文件指针 `yyin` 读取字符串，如果你没有设置 `yyin`，它默认为标准输入，输出到文件指针 `yyout`，如果没有设置，默认为标准输出。你也可以在到文件尾才调用的 `yywrap()` 函数中修改 `yyin`，它允许你打开另外一个文件，然后继续解析。

如果是这种情况（继续解析文件），让它返回0，如果你想结束解析这个文件，让它返回1。

每次调用 `yylex()` 会返回一个表示一个标示类型的数值。告诉 `YACC` 什么标示被读取。这个标示可能有值，如果有的话它的值会被放在 `yylval` 中。

`yylval` 默认的类型是 `int`。但是你可以在 `YACC` 文件中通过 `#define YYSTYPE` 来重新定义它。

词法分析需要访问变量 `yylval`，所以你需要在词法分析器中申明它为一个扩展变量。基本的 `YACC` 是没有为你做这些的，所以你必须自己添加如下的代码到词法分析器中， 在 `#include <y.tab.h>`后面：

```
extern YYSTYPE yylval;
```

## 标示值

我们之前提到的，`yylex()` 需要返回它遇到的标示和把它的值赋值给 `yylval`。当这些标示通过 `%token` 命令定义的时候，它们被分配了一个 `id`。这个 `id` 从 256 开始。

因为这样，我们就可能让所有的 ASCII 字符作为一个标示。假如说我们现在正在写一个计算器，到现在我们写的词法分析器如下：

```
[0-9]+		yylval = atoi(yytext); return NUMBER;
[ \n]+		/ eat whitespace */;
-			return MINUS;
\*			return MULT;
\+			return PLUS;
``` 

我们的 `YACC` 的语法包含下面的内容：

```
exp:	NUMBER
	| exp PLUS exp
	| exp MINUS exp
	exp NULT exp
```

可以不需要很复杂的。通过使用字符表示能用数字标示的标示 `id`，我们可以像下面重新写我们的词法分析器：

```
[0-9]+ 	yylval=atoi(yytext); return NUMBER;
[ \n]+		/* eat whitespace */
.			return (int) yytext[0];
```

最后面的一个点匹配所有的单个字符，否则不匹配。

我们的 `YACC` 的语法将会如下：

```
exp:	NUMBER
	| exp '+' exp
	| exp '-' exp
	| exp '*' exp
```

现在更简洁明了。你不需要在头部使用 `%token` 声明这些 `ASCII` 的标示，它们可以直接使用。

这种结构还有另外一个好处，`Lex` 将会匹配到所有我们传给它的，避免默认的输出不匹配的输入。如果用户使用这个计算机输入了 `^`, 它将会生成一个解析错误，而不是被输出到标准输出。


## 递归: 右边是错的

递归是 `YACC` 重要的一部分。你不可能制定一个只包含一些列独立的命令或状态。`YACC` 只关注第一条规则，或者是使用 `%start` 符号定义为开始规则的那一条。

递归在 `YACC` 有两种方式：左和右。你大部分时间用的都是左递归，如下：

```
commands: /* empty */
		| commands command
```

它告诉我们： `command` 可以是空或者由很多命令组成的 `commonds` 后面跟着 `command`。 `YACC` 的工作即它可以轻松的截断前面的单独的命令组并减少它们。

相比较右递归，令人疑惑的是大部分人觉得看起来更好：

```
commands: /* empty */
		| command commands
```

但是这个是非常昂贵的。如果被用于 `%start` 规则，`YACC` 需要将你在文件中定义的所有的命令都保存在栈中，这将会耗费很多内存。所以当解析长的像全部文件的声明一定要使用左递归。 有时候也很难避免使用右递归，但如果你的声明不是很长，就不需要强行改成使用左递归。

如果你有符号或是其他终止(分开)你的命令，右递归看起来非常自然，但是仍旧是非常昂贵的：

```
commands: /* empty */
		: command SEMICOLON commands
```

正确的方式是使用左递归:

```
commands:	/* empty */
		| commands command SEMICOLON
```
这个教程的最早版本是误用的右递归，多谢 `Markus Triska` 友善的提醒我。


## 高级 `yylval: %union`

目前，我们需要定义 `yylval` 的类型，但是并不是总是合适的，我们经常要处理不同数据类型的数据。返回我们假设的恒温控制器，如果我们想像下面一样选择一个加热器控制温度：

```
heater mainbuiling
	Selected 'mainbuiling' heater
target temperature 23
	'mainbuiling' heater target temperature now 23
```

上面的调用 `yylval` 是联合体，可以处理整形数据和字符串，但不是同时的。

假设我们通过使用 `#define YYSTYPE` 来先告诉 `YACC` `yylval` 支持什么类型，我们想得到的就是定义 `YYSTYPE` 是一个联合体，`YACC` 提供了很简单的方法，就是 `%union` 声明。

根据示例4来编写示例7的 `YACC` 语法，如下：

```
%token TOKHEATER TOKHEAT TOKTARGET TOKTEMPERATURE

%union
{
	int number;
	char *string;
}

%token <number> STATE
%token <number> NUMBER
%token <string> WORD
```

我们定义了一个包含数字和字符串的联合体。当使用了扩展的 `%token` 语法，告诉 `YACC` 每一个标示应该访问联合体的哪一部分。

在这个示例中，我们让标示 `STATE` 使用整数，用来读取温度的标示 `NUMBER` 也是使用整数，然后标示 `WORD` 使用字符串。

词法解析文件也有一点改动：

```
%{
#include <stdio.h>
#include <string.h>
#include "y.tab.h"
%}

%%

[0-9]+ 	yylval.number = atoi(yytext); return NUMBER;
heater		return TOKHEATER;
heat		return TOKHEAT;
on|off		yylval.number = !strcmp(yytext, "on"); return STATE;
target		return TOKTARGET;
temperature	return TOKTEMPERATURE;
[a-z0-9]+	yylval.string = strdup(yytext); return WORD;
\n			/* ignore end of line */;
[ \t]+		/* ignore whitespace */;
``` 

如你所见，我们不再直接访问 `yylval`，而是加了下标来表明我们访问哪一部分。但是在 `YACC` 语法中不需要做任何事情，因为 `YACC` 已经帮我们处理好了：

```
heater_select:
	TOKHEATER WORD
	{
		printf("\tSelected heater '%s'", $2);
		heater=$2;
	}
```

因为上面的 `%token` 已经声明，所以 `YACC` 自动选择了联合体里面的字符串成员。注意我们存储了 `$2` 的副本，它将会告诉用户他正在对哪一个加热器发送命令：

```
target_set:
	TOKTARGET TOKTEMPERATURE NUMBER
	{
		printf("\tHeater '%s' temperature set to %d\n", heater, $3);
	}
```

查看 `example7.y` 了解更多信息。