# 调试

调试工具在学习的时候非常重要。幸运的是，`YACC` 给了我们很多反馈，这些反馈是以一些开销为代价的，所以你必须提供可选的编译参数来开启。

当使用 `YACC` 生成语法解析器的时候，添加 `--debug` 和 `--verbose` 参数，然后在生成的 `c` 的文件的头部添加下面的一行：

```
int yydebug = 1;
```

还会生成一个告诉你创建了哪些状态机的文件 `y.output`。

当执行生成的可执行文件时，它将会输出很多当前正在发生什么事情，这包括现在状态机中什么状态，什么标示正在被读取。

`Peter Jinks` 写了一篇包含了常见错误以及怎么解决的的 [`debug` 文档](http://www.cs.man.ac.uk/~pjj/cs2121/debug.html)。

## 状态机
 
在 `YACC` 解析器内部运行了一个状态机，顾名思义，这个状态机可以处在很多状态，然后这些规则管理状态机从一个状态切换到另一个状态。这一切都从我们之前提到的根规则开始。

从示例7的 `y.out` 引用的输出如下：


```
state 0
	ZONETOK	, and go to state 1
	$default 	reduce using rule 1 (commands)
	commands	go to state 29
	command	go to state 2
	zone_set	go to state 3
```

这个状态默认使用 `commands` 这个规则 `reduce`。这就是我们前面提过的从单个命令语句定义的递归的 `commands`，后面跟一个分号，然后再跟尽可能多的指令。

这个状态一直 `reduce`，直到遇到它能理解的标示，在这个例子中是标示 `ZONETOK`(单词 `word`)。然后切换到状态1，处理后面的 `zone` 指令：

state 1
	zone_set ->	ZONETOK . quotedname zonecontent (rule 4)
	QUOTE 			, and to to state 4
	quotedname	go to state 5
	

第一行有一个点 `.`， 他表示我们在那里即：我们已经遇到 `ZONETOK` 现在正在寻找 `quotedname`。显然的，`quotedname` 以标示 `QUOTE` 开始，然后切换到状态4。

为了了解的跟多，加上上面介绍的参数编译示例7。


## `shift/reduce` 和 `reduce/reduce` 冲突

无论什么时候当 `YACC` 警告你有冲突，你可能遭遇到了麻烦。解决这些冲突某种程度上是教你更多关于你的语言的艺术，超过了你可能想知道的。

问题围绕怎么解释一串标示(`token`)。假设我们设计了一门语言接受下面的命令：

```
delete heater all
delete heater number1
```

为了达到这个目的，我们定义了下面的语法规则：

```
delete_heaters:
	TOKEDLETE TOKHEADER mode
	{
		deleteheaters($3);
	}

mode:	WORD

delete_a_heater:
	TOKDELETE TOKHEATER WORD
	{
		delete($3);
	}
```

你可能已经发现了问题。状态机开始读取一个 `delete`，然后需要根据下一个标示来判断去哪里，后面的一个标示可能是一个指示怎么删除 `heaters` 的模式，或者是 `heater` 的名字。

然而对这两个指令的问题是，后面标示都是 `WORD`。所以 `YACC` 不知道怎么处理。 这会导致 `reduce/reduce`  警告，进一步的警告 `delete_a_header` 规则永远不会执行。

在这个例子中的冲突很容易解决，但是很多时候是非常的难的。当使用 `YACC` 生成语法解析文件时添加`--verbose` 参数之后生成的 `y.output` 文件非常有用。

