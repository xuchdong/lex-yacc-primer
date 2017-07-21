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
