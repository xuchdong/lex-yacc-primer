# 使用 C++ 制作一个解析器

尽管 `Lex` 和 `YACC` 比 `C++` 早，但是我们也可以生成`C++` 版本的解析器。`Flex` 包含一个选项就可以生成 `C++` 版本词法解析器，我们不会使用这个，因为 `YACC` 不知道怎么直接处理它。

我更喜欢的使用 `C++` 制作一个解析器的方法是让 `Lex` 生成一个 `c` 文件，让 `YACC` 生成 `C++` 文件，当链接你的应用的时候，可能会导致一些错误，这是因为 `C++` 代码默认的找不到 `c` 的函数，除非你告诉他他们是 `c` 函数。

为了实现上面的目的，在 `YACC` 文件中添加 `c` 的部分如下：

```
extern "C"
{
	int yyparse(void);
	int yylex(void);
	int yywrap()
	{
		return 1;
	}
}
```

如果你想声明或是改变 `yydebug`，你必须添加如下的部分：

```
extern int yydebug;

main()
{
	yydebug = 1;
	yyparse();
}
```

这是因为 `C++` 的 `One Definition Rue(ODR)`，不允许 `yydebug` 定义多次。

你会发现你需要在 `Lex` 文件中重复定义 `YYSTYPE`，这是因为 `C++` 的严格的类型检查。

你需要像下面一样编译：

```
lex bindconfig2.l
yacc --verbose --debug -d bindconfig2.l -o bindconfig2.cc
cc -c lex.yy.c -o lex.yy.o
c++ lex.yy.o bindconfig2.cc -o bindconfig2
```

注意，因为 `-o` 参数的关系，你必须考虑到头文件不是 `y.tab.h`，而是 `bindconfig2.cc.h`。

总结： 不要想着将你的词法解析文件输出成 `C++` 而是 `c`，让 `YACC` 输出成 `C++` 使用 `extern "C"` 告诉编译器有一些函数是 `c` 函数。 
