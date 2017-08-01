# YACC
`YACC` 可以解析由已经确认的标示组成的输入流，这清楚的描述了 `YACC` 和 `Lex` 之间的关系，`YACC` 不知道输入流是什么，他需要预先处理好的标示。 当然你也可以写自己的标示化程序，我们将这个部分的工作交给了 `Lex`。


## 一个简单的恒温控制器

假设我们有一个恒温器，我们想用一种简单的语言来控制它。一个简单的和恒温器的会话如下：

```
heat on
    Heater on!
heat off
    Heater off!
target temperature 22
    New temperature set!
```

我们必须注册的标示(`token`)有：`heat`，`on/off(STATE)`，`target`, `temperature`, `NUMBER`。

`Lex` 标示化（示例4）如下：

```
%{
#include <stdio.h>
#include "y.tab.h"
%}
%%
[0-9]+          return NUMBER;
heat            return TOKHEAT;
on|off          return STATE;
target          return TOKTARGET;
temperature     return TOKTEMPERATURE;
\n              /* ignore end of line */
[ \t]+          /* ignore whitespace */
%%
```

我们需要注意2点重要的变化。1. 我们 `include` 头文件 `y.tab.h`；2. 我们不再打印输出，而是返回标示(`token`)。有这些变化主要是因为我们会将值传给 `YACC`，而不关心我们把什么输出到屏幕。`y.tab.h` 中定义了这些标示(`token`)。

但是 `y.tab.h` 从哪里来？ 它从我们将要创建的语法文件，由 `YACC` 生成。因为我们的语言非常基础，所以语法如下：

```
commands: /* empty */
    | commands command
    ;
			
command: 
    heat_switch
    | target_set
    ;
 
heat_switch:
    TOKHEAT STATE
    {
        printf("\tHeat turned on or off\n");
    }

target_set:
    TOKTARGET TOKTEMPERATURE NUMBER
    {
        printf("\tTemperature set\n);
    }
``` 

第一部分被叫做根(`root`)。它告诉我们有指令集，由单独的指令构成。就像你看到的，这些规则是递归的，因为它可以再一次包含指令集。这意味着这个程序能递归的一个一个的执行一系列命令。阅读 [`Lex` 和 `YACC` 内部是怎么工作的](inter-lex-yacc.md) 查看关于递归的重要信息。

第二条规则定义了具体的有什么命令。我们仅仅支持两种指令，`heat_switch` 和 `target_set`，这就是符号 `|` 所表示的（一个命令由 `heat_switch` 或是 `target_set` 构成）。

`heat_switch` 由表示 `heat` 的标示(`token`) `TOKHEAT` 和一个我们在 `Lex` 文件中定义的 `on` 或 `off` 的 `STATE`。

`target_set` 相对复杂一点，由 `TOKTARGET` (单词 `target`)，`TOKTEMPERATURE` (单词 `temperature`) 和一个 `NUMBER` 构成。

#### 一个完整的 `YACC` 文件

之前的章节仅仅显示了 `YACC` 文件的语法部分，这里是我们忽略的头的部分：
 
```
%{
#include <stdio.h>
#include <string.h>

void yyerror(const char *str)
{
	fprintf(stderr, "error: %s\n", str);
}

int yywrap()
{
	return 1;
}

main()
{
	yyparse();
}
%}

%token NUMBER TOKHEAT STATE TOKTARGET TOKTEMPERATURE
```

当发现错误的时候 `yyerror()` 被 `YACC` 调用，我们这里简单的输出传过来的错误信息，但是这里可以有更智能的操作。参考后面的[延伸阅读](further-reading.md)。

`yywrap()` 被用于继续从其他文件读取内容。当一个文件结束(`EOF`)时它被调用，然后打开另外一个文件，然后返回0。或者返回1，标明这是真正的结束。了解更多的信息请查看[`Lex` 和 `YACC` 内部是怎么工作的](inter-lex-yacc.md)。

接下来是 `main()` 函数，它除了开始程序意外不做任何事情。

最后一行简单定义的标示(`tokens`)将会被使用，当 `YACC` 使用 `-d` 参数时他们会被输出到 `y.tab.h`文件中。

#### 编译运行恒温控制器

```
lex example4.l
yacc -d example4.y
cc lex.yy.c y.tab.c -o example4
```

这里又了一点点变化，我们调用了 `YACC` 编译我们的语法，创建 `y.tab.c`和 `y.tab.h` 文件。然后我们跟之前一样调用 `Lex`。当编译的时候，我们移除了 `-ll` 标志，这是因为我们有了自己的 `main()` 函数，所以不需要 `libl` 提供。

> 注意：如果编译的时候提示找不到 `yylval`, 在 example4.l 的 `#include <y.tab.h>` 下添加
> `extern YYSTYPE yylval;` 
> 这个将在[`Lex` 和 `YACC` 内部是怎么工作的](inter-lex-yacc.md) 中解释。

下面是一个简单的会话：

```
$./example4
heat on
	Heat turned on or off
heat off
	Heat turned on of off
target temperature 10
	Temperature set
target humidity 20
error: parse error
```

这并不完全是我们实现的，但是为了保持学习的曲线可控，而不是将所有的难的东西一次被呈现出来。

## 扩展恒温控制器处理参数

就像我们看到的，我们现在已经完全正确的解析了恒温控制器的参数，甚至能显示错误信息。但是正如你有可能猜到的，这个程序不知道做什么，它不能接受任何我们传入的值。 

让我们开始添加设定新的温度目标的功能。为了添加这个功能，我们需要学习在 `Lex` 文件中 `NUMBER` 匹配之后把它转化成一个后面能被 `YACC` 读取的整数。

无论什么时候 `Lex` 匹配到目标，它都将匹配到的内容赋值给字符串变量 `yytext`， `YACC` 希望顺序的在变量 ``yylval` 中找到值。在示例5中，我们将看到明显的解决方法：

```
%{
#include <stdio.h>
#include <y.tab.h>
%}
%%
[0-9]+      yylval=atoi(yytex); return NUMBER;
heat        return  TOKHEAT;
on|off      yylval=!strcmp(yytex, "on"); return STATE;
target      return TOKTARGET;
temperature return TOKTEMPERATURE;
\n          /* ignore end of line */
[ \t]+      /* ignore whitespace */
%%
```
就像你看到的，我们对 `yytext` 执行 `atoi()` 函数，然后将结果赋值给 `YACC` 可以读取的 `yylval`。我们对 `STATE` 匹配做了差不多同样的事情，拿 `yytext` 和 `on` 比较，如果相等的话就对 `yylval` 赋值为1。请注意 `Lex` 文件中 `on` 和 `off` 有一个竖线 `|` 分隔，这将会处理的更快，但是我们想展示更复杂的规则和动作。

接下来我们学习 `YACC` 怎么处理。 在 `Lex` 文件中的 `yylval` 在 `YACC` 中有不同的名字。让我们来解释设置新目标温度的规则：

```
target_set:
	TOKTARGET TOKTEMPERATURE NUMBER
	{
		printf("\tTemperature set to %d\n", $3);
	}
```

为了访问规则的第三部分的值(`NUMBER`)，我们使用了 `$3`，无论什么时候 `yylex()` 返回, `yylval` 的内容将会附在终端上，这些值可以使用 `$` 这种结构访问。

为了更深的解释，让我来观察新的 `heat_switch` 规则：

```
heat_switch:
	TOKHEAT STATE
	{
		if($2)
			printf("\tHeat turned on\n");
		else
			printf("\tHeat turned off\n");
	}
```
如果你执行 example5， 它将会正确输出你的输入。


## 解析一个配置文件

让我们重复之前提到过的配置文件的一部分：

```
zone "." {
	type hint;
	file "/etc/bind/db.root";
}
```

记得我们之前已经为这个配置文件写过一个词法分析器。现在我们需要做的是写一个 `YACC` 的语法和改变词法分析器让它返回 `YACC` 可以理解的值。

示例6的词法分析器如下：

```
%{
#include <stdio.h>
#include "y.tab.h"
%}

%%

zone                    return ZONETOK;
file                    return FILETOK;
[a-zA-Z][a-zA-Z0-9]*    yylval = strdup(yytext); return WORD;
[a-zA-Z0-9\/.-]+        yylval = strdup(yytext); return FILENAME;
\"                      return QUOTRE;
\{                      return OBRACE;
\}                      return EBRACE;
;                       return SEMICOLON;
\n                      /* ignore EOL */;
[ \t]+                  /* ignore whitespace */;

%%
```

如果你仔细看，你会发现 `yylval` 变化了，我们不再希望它是一个整数了，实际上假设它是一个字符串，为了保持简单，我们调用了 `strdup` 浪费了一些空间，请注意，这将在只解析文件一次就退出的地方不会是一个问题。

为了告诉 `YACC` `yyval` 为新的类型，我们添加下面一行到 `YACC` 语法文件中：

```
#define YYSTYPE char *
``` 

语法本身变得更加复杂。为了容易理解吸收，我们抽出其中的一部分，如下：

```
commands:
	| commands commond SEMICOLON
	;

command:
	zone_set
	;
			
zone_set:
	ZONETOK quotedname zonecontent
	{
		printf("Complete zone for '%s' found\n", $2);
	}
	;
			
```

这是介绍，包括我们之前提到的递归的根(`root`)。 请注意，我们定义命令命令使用分号(`;`)隔开。我们定义了一种命令 `zone_test`。它包含标示 `ZONETOK`，后面跟着命令`quotedname` 和 `zonecontent`。命令 `zoneconet` 非常简单：

```
zonecontent:
	OBRACE zonestatements EBRACE
```

它需要以 `{` 开始，然后是 `zonestatements` 命令，再然后是 `}`。

```
quotedname:
	QUOTE FILENAME QUOTE
	{
		$$ = $2;
	}
```

这个部分定义了 `quotedname`，一个文件名在两个引号之间。这里有一点特殊的是：`quotedname` 命令的返回值是 `FILENAME` 的值，这意味着 `quotedname` 的值是没有引号的。

魔法指令 `$$=$2` 指令所做的事情就是告诉我们：我的值是第二部分的值。如果 `quotedname` 被其他规则引用，你可以访问它通过 `$` 结构，你将可以获取到我们通过 `$$=$2` 设给它的值。

```
// 注意： 该语法阻止了文件名中有 `.` 和 `/`
zonesatements:
	|
	zonestatements zonestatement SEMICOLON
	;

zonestatement:
	statements
	| FILETOK quotedname
	{
		printf("A zonefile name `%s` was encountered\n", $2);
	}
	;
	
```

这是一个一般的声明，它包含了所有的声明在 `block` 中。我们再来看下面的递归：

 ```
 block:
 	OBRACE zonestatements EBRACE SEMICOLON
 	;
 	
 statements:
 	|statements statement
 	;
 	
 statement:
 	WORD | block | quotedname
 ```
 
这里定义了 `block`, 在里面可以发现`statements`。

当我们执行之后，输入如下：

```
$./example6
zone "." {
	type hint;
	file "/etc/bind/db.root";
	type hint;
}
A zonefile name '/etc/bind/db.root' was encountered
Complete zone for '.' found
```
