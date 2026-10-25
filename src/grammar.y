%token COMMA LBRACE RBRACE LPAREN RPAREN SEMI COLON EQ UNDERSCORE PERCENT DOT
%token MATCH CASE FUNCTION TYPE EXTERNAL INTERNAL IN OUT INOUT REF PTR
%token CONTINUE BREAK RUNTIME
%token IDENTIFIER STRING INTEGER FLOAT CHAR MACRO NIL

%%
Program: BlockBody
Expressions: Expressions COMMA Expression | Expression
NonAttributedExpression: Block | Call | Function | Type | MatchExpression | RuntimeExpression | WrappedExpressions | Literal
WrappedExpressions: LPAREN Expressions RPAREN
Expression: Block | Call | Function | Type | MatchExpression | RuntimeExpression | WrappedExpressions | AttributedExpression | Literal
Block: LBRACE BlockBody RBRACE
BlockBody: Statements Expressions | Expressions 
MatchExpression: MATCH LPAREN Expression RPAREN LBRACE MatchCases RBRACE
MatchCases: MatchCases MatchCase | MatchCase
MatchCase: CASE Expression COLON Expressions SEMI
Function: FUNCTION LPAREN FunctionParameters RPAREN FunctionAttributes FunctionBody PERCENT
FunctionParameters: FunctionParameters COMMA FunctionParameter | FunctionParameter
FunctionParameter: AccessAttribute IDENTIFIER TypeAttribute
FunctionAttributes: FunctionAttributes FunctionAttribute | FunctionAttribute
FunctionAttribute: FunctionExternalAttribute | FunctionInternalAttribute
FunctionExternalAttribute: EXTERNAL LPAREN Expressions RPAREN
FunctionInternalAttribute: INTERNAL LPAREN Expressions RPAREN
FunctionBody:  COLON Expressions | /* empty */
Call: NonAttributedExpression LPAREN Expressions RPAREN
RuntimeExpression: RUNTIME LPAREN Expression RPAREN
Literal: STRING | INTEGER | FLOAT | CHAR | Identifier | MACRO | NIL
Identifier: Identifier DOT IDENTIFIER | IDENTIFIER
Type: TYPE LPAREN Expression RPAREN LBRACE TypeEntries RBRACE
Statements: Statements Statement | Statement
Statement: CallStatement | AssignmentStatement | ContinueStatement | BreakStatement | LabelStatement
CallStatement: Call SEMI
AssignmentStatement: AssignmentTarget EQ Expressions SEMI
AssignmentTarget: AccessAttribute IDENTIFIER TypeAttribute | Identifier | UNDERSCORE
ContinueStatement: CONTINUE IDENTIFIER Expressions SEMI
BreakStatement: BREAK IDENTIFIER Expressions SEMI
LabelStatement: IDENTIFIER COLON MatchExpression SEMI | IDENTIFIER COLON SEMI
TypeAttributeOptional: TypeAttribute | /* empty */
TypeAttribute: COLON Expression
TypeEntries: TypeEntries TypeEntry | TypeEntry
TypeEntry: IDENTIFIER TypeAttributeOptional SEMI
AccessAttribute: IN | OUT | INOUT
PointerAttribute: PTR | REF
AttributedExpression: AccessAttribute Expression | PointerAttribute AttributedExpression
%%